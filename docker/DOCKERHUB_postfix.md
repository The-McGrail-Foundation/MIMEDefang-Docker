# mimedefang/postfix

[MIMEDefang](https://www.mimedefang.org/) email filter running alongside
**Postfix** as the MTA, maintained by
[The McGrail Foundation](https://github.com/The-McGrail-Foundation/MIMEDefang).

MIMEDefang hooks into Postfix via the Milter protocol (`smtpd_milters`) and
lets you express your mail-filtering policy in Perl — stripping attachments,
adding headers, calling SpamAssassin, querying external APIs, and more.

---

## Tags

| Tag | Purpose |
|-----|---------|
| `latest` | Current stable release – production image (no build tools) |
| `vX.Y` | Pinned release, e.g. `v3.7` |
| `ci` | CI/CD image – full build toolchain kept |

---

## Quick start

```bash
docker run -d \
  -e MAIL_DOMAIN=example.com \
  -e MAIL_HOST=mail.example.com \
  -v /path/to/my-filter:/etc/mail/mimedefang-filter:ro \
  -p 25:25 \
  mimedefang/postfix:latest
```

If no filter is bind-mounted, a built-in pass-through filter is used so the
container starts cleanly out of the box.

---

## Docker Compose (production)

```yaml
services:
  postfix:
    image: mimedefang/postfix:latest
    hostname: mail.example.com
    restart: unless-stopped
    environment:
      MAIL_DOMAIN: "example.com"
      MAIL_HOST:   "mail.example.com"
      TZ:          "Europe/Rome"
    ports:
      - "25:25"
    volumes:
      - ./mimedefang-filter:/etc/mail/mimedefang-filter:ro
      - postfix-spool:/var/spool/MIMEDefang
      - postfix-quarantine:/var/spool/MD-Quarantine

volumes:
  postfix-spool:
  postfix-quarantine:
```

---

## Environment variables

All variables have sensible defaults; override only what you need.

### Identity

| Variable | Default | Description |
|----------|---------|-------------|
| `MAIL_DOMAIN` | `example.com` | `mydomain` in `main.cf` |
| `MAIL_HOST` | `mail.example.com` | `myhostname` in `main.cf` |
| `RELAY_HOST` | *(empty)* | Optional `relayhost`, e.g. `[smtp.isp.com]:587` |
| `RELAY_NETS` | `127.0.0.0/8 [::1]/128` | `mynetworks` — hosts allowed to relay |

### MIMEDefang multiplexor

| Variable | Default | Description |
|----------|---------|-------------|
| `MIN_WORKERS` | `2` | Minimum number of Perl worker processes |
| `MAX_WORKERS` | `10` | Maximum number of Perl worker processes |
| `MAX_IDLE` | `2` | Workers to keep alive when idle |
| `SPOOL_DIR` | `/var/spool/MIMEDefang` | Multiplexor and milter socket directory |

### Postfix / SMTP

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_PORT` | `25` | SMTP listen port (informational; also set in `ports:`) |
| `ENABLE_SUBMISSION` | `no` | Set to `yes` to enable port 587 submission service |

### System

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Container timezone, e.g. `Europe/Rome` |

---

## Volumes

| Mount path | Purpose |
|------------|---------|
| `/etc/mail/mimedefang-filter` | **Your Perl filter** — bind-mount required for non-trivial use |
| `/etc/postfix/extra.cf` | Optional: extra `key = value` lines appended to `main.cf` at startup |
| `/var/spool/MIMEDefang` | Milter socket + spool — persist to survive container restarts |
| `/var/spool/MD-Quarantine` | Quarantine directory |
| `/etc/pki/tls/mimedefang` | TLS certificates (`key.pem` + `cert.pem`) |

### Injecting extra Postfix settings

For any `main.cf` directive not covered by an environment variable, create a
plain text file with one `key = value` per line and bind-mount it:

```
# extra.cf
message_size_limit = 52428800
smtpd_helo_required = yes
```

```yaml
volumes:
  - ./extra.cf:/etc/postfix/extra.cf:ro
```

---

## Build-time arguments

When building the image yourself (see [GitHub](https://github.com/The-McGrail-Foundation/MIMEDefang)):

| ARG | Default | Description |
|-----|---------|-------------|
| `BASE_IMAGE` | `almalinux:9` | Base OS — any RHEL-compatible image works |
| `MIMEDEFANG_VER` | `v3.7` | Git tag to build from |

```bash
docker build \
  --build-arg MIMEDEFANG_VER=v3.7 \
  --target prod \
  -t mimedefang/postfix:v3.7 .
```

---

## Build targets

```bash
# Build the CI image
docker build --target ci -t mimedefang/postfix:ci .

# Run the test suite
docker compose -f docker-compose-postfix.yml --profile ci \
  up --build --exit-code-from mimedefang-postfix-ci
```

---

## Writing a filter

The filter is a plain Perl file. A minimal example:

```perl
use strict;
use warnings;

sub filter_begin  { }
sub filter        { return action_accept(); }
sub filter_end    { }

1;
```

Mount it at `/etc/mail/mimedefang-filter` and restart the container. Full
documentation: [`mimedefang-filter(5)`](https://www.mimedefang.org/) and the
[examples directory](https://github.com/The-McGrail-Foundation/MIMEDefang/tree/master/examples)
in the source tree.

---

## Links

- [mimedefang.org](https://www.mimedefang.org/)
- [Source on GitHub](https://github.com/The-McGrail-Foundation/MIMEDefang)
- [Issue tracker](https://github.com/The-McGrail-Foundation/MIMEDefang/issues)
- [mimedefang/sendmail](https://hub.docker.com/r/mimedefang/sendmail) — same filter, Sendmail MTA
