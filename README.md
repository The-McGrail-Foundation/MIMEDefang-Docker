# MIMEDefang Docker Images

Official Docker images for [MIMEDefang](https://www.mimedefang.org/), the
open-source email filter maintained by
[The McGrail Foundation](https://github.com/The-McGrail-Foundation/MIMEDefang).

Two images are provided — one for each supported MTA:

| Image | MTA | DockerHub |
|-------|-----|-----------|
| `mimedefang/postfix` | Postfix | [hub.docker.com/r/mimedefang/postfix](https://hub.docker.com/r/mimedefang/postfix) |
| `mimedefang/sendmail` | Sendmail | [hub.docker.com/r/mimedefang/sendmail](https://hub.docker.com/r/mimedefang/sendmail) |

MIMEDefang hooks into the MTA via the Milter protocol and lets you express your
mail-filtering policy in Perl — stripping attachments, adding headers, calling
SpamAssassin, querying external APIs, and more.

---

## Repository layout

```
Dockerfile.postfix          Multi-stage Dockerfile for the Postfix image
Dockerfile.sendmail         Multi-stage Dockerfile for the Sendmail image
docker-compose-postfix.yml  Compose file – CI and production profiles (Postfix)
docker-compose-sendmail.yml Compose file – CI and production profiles (Sendmail)
docker/
  entrypoint-postfix.sh     Container entrypoint (configures Postfix + MIMEDefang)
  entrypoint-sendmail.sh    Container entrypoint (configures Sendmail + MIMEDefang)
  mimedefang-filter.default Built-in pass-through filter (used when none is mounted)
  DOCKERHUB_postfix.md      DockerHub description page for mimedefang/postfix
  DOCKERHUB_sendmail.md     DockerHub description page for mimedefang/sendmail
```

---

## Tags

| Tag | Purpose |
|-----|---------|
| `latest` | Current stable release — lean production image (no build tools) |
| `vX.Y` | Pinned release, e.g. `v3.7` |
| `ci` | CI/CD image — full build toolchain kept, used by MIMEDefang's test suite |

---

## Building images

```bash
# Postfix — production image
docker build --target prod --build-arg MIMEDEFANG_VER=v3.7 \
    -t mimedefang/postfix:latest -f Dockerfile.postfix .

# Postfix — CI image (keeps compiler + test deps)
docker build --target ci -t mimedefang/postfix:ci -f Dockerfile.postfix .

# Sendmail — production image
docker build --target prod --build-arg MIMEDEFANG_VER=v3.7 \
    -t mimedefang/sendmail:latest -f Dockerfile.sendmail .

# Sendmail — CI image
docker build --target ci -t mimedefang/sendmail:ci -f Dockerfile.sendmail .
```

Build-time arguments:

| ARG | Default | Description |
|-----|---------|-------------|
| `BASE_IMAGE` | `almalinux:9` | Base OS image |
| `MIMEDEFANG_VER` | `v3.7` | MIMEDefang git tag to build from |

---

## CI usage

The `ci` profile is used by the MIMEDefang test suite. It bind-mounts the
source tree, builds an RPM inside the container, and runs the test suite:

```bash
# Postfix
docker compose -f docker-compose-postfix.yml --profile ci \
    up --build --exit-code-from mimedefang-postfix-ci

# Sendmail
docker compose -f docker-compose-sendmail.yml --profile ci \
    up --build --exit-code-from mimedefang-sendmail-ci
```

---

## Production usage

```bash
# Postfix
docker compose -f docker-compose-postfix.yml --profile prod up -d

# Sendmail
docker compose -f docker-compose-sendmail.yml --profile prod up -d
```

A minimal `mimedefang-filter` is included in the image so the container starts
cleanly out of the box. Mount your own filter to customise behaviour:

```yaml
volumes:
  - ./mimedefang-filter:/etc/mail/mimedefang-filter:ro
```

---

## DockerHub reference pages

Detailed environment variables, volume mount points, and usage examples:

- [docker/DOCKERHUB_postfix.md](docker/DOCKERHUB_postfix.md)
- [docker/DOCKERHUB_sendmail.md](docker/DOCKERHUB_sendmail.md)

---

## Links

- [mimedefang.org](https://www.mimedefang.org/)
- [MIMEDefang source on GitHub](https://github.com/The-McGrail-Foundation/MIMEDefang)
- [Issue tracker](https://github.com/The-McGrail-Foundation/MIMEDefang/issues)
