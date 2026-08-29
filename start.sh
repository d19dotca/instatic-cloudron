#!/bin/bash
set -euo pipefail

umask 077
mkdir -p /app/data/uploads /app/data/secrets /run/instatic
chown -R cloudron:cloudron /app/data /run/instatic

secret_file=/app/data/secrets/instatic-secret-key
if [[ ! -s "${secret_file}" ]]; then
    openssl rand -hex 32 > "${secret_file}"
fi
chown cloudron:cloudron "${secret_file}"
chmod 0600 "${secret_file}"

if [[ -f /app/data/env ]]; then
    # This is an administrator-owned shell environment file. Do not place
    # Cloudron addon credentials here; they are injected on every start.
    # shellcheck disable=SC1091
    source /app/data/env
fi

: "${CLOUDRON_POSTGRESQL_URL:?Cloudron PostgreSQL addon is not configured}"
: "${CLOUDRON_APP_ORIGIN:?Cloudron app origin is not configured}"
: "${CLOUDRON_MAIL_SMTP_SERVER:?Cloudron sendmail addon is not configured}"
: "${CLOUDRON_MAIL_SMTP_PORT:?Cloudron sendmail addon port is not configured}"
: "${CLOUDRON_MAIL_SMTP_USERNAME:?Cloudron sendmail username is not configured}"
: "${CLOUDRON_MAIL_SMTP_PASSWORD:?Cloudron sendmail password is not configured}"
: "${CLOUDRON_MAIL_FROM:?Cloudron sender address is not configured}"

printf '%s' "${CLOUDRON_MAIL_SMTP_PASSWORD}" > /run/instatic/msmtp-password
chmod 0600 /run/instatic/msmtp-password
chown cloudron:cloudron /run/instatic/msmtp-password

cat > /run/instatic/msmtprc <<EOF
defaults
auth plain
tls off
account cloudron
host ${CLOUDRON_MAIL_SMTP_SERVER}
port ${CLOUDRON_MAIL_SMTP_PORT}
user ${CLOUDRON_MAIL_SMTP_USERNAME}
passwordeval cat /run/instatic/msmtp-password
from ${CLOUDRON_MAIL_FROM}
set_from_header on
account default : cloudron
EOF
chmod 0600 /run/instatic/msmtprc
chown cloudron:cloudron /run/instatic/msmtprc

export DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
export PUBLIC_ORIGIN="${PUBLIC_ORIGIN:-${CLOUDRON_APP_ORIGIN}}"
export INSTATIC_SECRET_KEY
INSTATIC_SECRET_KEY=$(<"${secret_file}")
export INSTATIC_FORM_EMAIL_TO="${INSTATIC_FORM_EMAIL_TO:-${CLOUDRON_MAIL_FROM}}"
export INSTATIC_MSMTP_CONFIG=/run/instatic/msmtprc
export UPLOADS_DIR=/app/data/uploads
export STATIC_DIR=/app/code/dist
export PORT=3001

echo "Starting Instatic with PostgreSQL and persistent uploads at /app/data/uploads"
exec /usr/local/bin/gosu cloudron:cloudron /usr/local/bin/bun run /app/code/server/index.ts
