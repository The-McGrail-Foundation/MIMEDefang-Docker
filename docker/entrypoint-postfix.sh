#!/bin/sh
# =============================================================================
# entrypoint-postfix.sh – configure Postfix + MIMEDefang from environment vars
# =============================================================================
set -e

log() { echo "[entrypoint-postfix] $*"; }

# ---------------------------------------------------------------------------
# Timezone
# ---------------------------------------------------------------------------
if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
fi

# ---------------------------------------------------------------------------
# Default filter fallback
# ---------------------------------------------------------------------------
if [ ! -s /etc/mail/mimedefang-filter ]; then
    log "No filter at /etc/mail/mimedefang-filter – using built-in default"
    cp /etc/mail/mimedefang-filter.default /etc/mail/mimedefang-filter
fi
chmod 644 /etc/mail/mimedefang-filter

# ---------------------------------------------------------------------------
# Generate Postfix main.cf from environment variables
# ---------------------------------------------------------------------------
log "Configuring Postfix (domain=${MAIL_DOMAIN} host=${MAIL_HOST})"

postconf -e \
    "myhostname = ${MAIL_HOST}" \
    "mydomain   = ${MAIL_DOMAIN}" \
    "myorigin   = \$mydomain" \
    "mydestination = \$myhostname, localhost.\$mydomain, localhost" \
    "mynetworks = ${RELAY_NETS}" \
    "inet_interfaces = all" \
    "inet_protocols = all" \
    "smtpd_banner = \$myhostname ESMTP" \
    "smtpd_milters = unix:${SPOOL_DIR}/mimedefang.sock" \
    "non_smtpd_milters = unix:${SPOOL_DIR}/mimedefang.sock" \
    "milter_default_action = accept" \
    "milter_protocol = 6" \
    "milter_connect_timeout = 30s" \
    "milter_command_timeout  = 30s" \
    "milter_content_timeout  = 300s"

# Optional relay host
if [ -n "${RELAY_HOST}" ]; then
    postconf -e "relayhost = ${RELAY_HOST}"
fi

# Optional submission service on port 587
if [ "${ENABLE_SUBMISSION}" = "yes" ]; then
    # Enable the submission service in master.cf if not already active
    postconf -M "submission/inet=submission inet n - n - - smtpd"
    postconf -P "submission/inet/syslog_name=postfix/submission"
    postconf -P "submission/inet/smtpd_tls_security_level=may"
fi

# Merge optional extra.cf snippets (bind-mounted at /etc/postfix/extra.cf)
if [ -s /etc/postfix/extra.cf ]; then
    log "Merging /etc/postfix/extra.cf"
    while IFS='=' read -r key value; do
        # Skip blank lines and comments
        case "${key}" in ''|\#*) continue ;; esac
        postconf -e "${key} = ${value}"
    done < /etc/postfix/extra.cf
fi

# Rebuild lookup tables
newaliases 2>/dev/null || true

# ---------------------------------------------------------------------------
# Spool / quarantine directories
# ---------------------------------------------------------------------------
mkdir -p "${SPOOL_DIR}" /var/spool/MD-Quarantine /run/mimedefang
chown defang:defang "${SPOOL_DIR}" /var/spool/MD-Quarantine /run/mimedefang 2>/dev/null || true
chmod 700 "${SPOOL_DIR}" /var/spool/MD-Quarantine

# ---------------------------------------------------------------------------
# Start rsyslog
# ---------------------------------------------------------------------------
rsyslogd

# ---------------------------------------------------------------------------
# Start MIMEDefang multiplexor
# ---------------------------------------------------------------------------
log "Starting mimedefang-multiplexor (min=${MIN_WORKERS} max=${MAX_WORKERS} idle=${MAX_IDLE})"
/usr/local/bin/mimedefang-multiplexor \
    -p "${SPOOL_DIR}/mimedefang-multiplexor.sock" \
    -o "${SPOOL_DIR}/mimedefang-multiplexor.lock" \
    -m "${MIN_WORKERS}" \
    -x "${MAX_WORKERS}" \
    -i "${MAX_IDLE}" \
    -z "${SPOOL_DIR}" \
    -l &

sleep 1

# ---------------------------------------------------------------------------
# Start MIMEDefang (milter bridge)
# ---------------------------------------------------------------------------
log "Starting mimedefang"
rm -f "${SPOOL_DIR}/mimedefang.sock"
/usr/local/bin/mimedefang \
    -p "${SPOOL_DIR}/mimedefang.sock" \
    -m "${SPOOL_DIR}/mimedefang-multiplexor.sock" \
    -z "${SPOOL_DIR}" &

sleep 1

# ---------------------------------------------------------------------------
# Start Postfix in the foreground
# ---------------------------------------------------------------------------
log "Starting postfix (port ${SMTP_PORT})"
exec /usr/sbin/postfix start-fg
