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

export DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
export PUBLIC_ORIGIN="${PUBLIC_ORIGIN:-${CLOUDRON_APP_ORIGIN}}"
export INSTATIC_SECRET_KEY
INSTATIC_SECRET_KEY=$(<"${secret_file}")
export UPLOADS_DIR=/app/data/uploads
export STATIC_DIR=/app/code/dist
export PORT=3001

echo "Starting Instatic with PostgreSQL and persistent uploads at /app/data/uploads"
exec /usr/local/bin/gosu cloudron:cloudron /usr/local/bin/bun run /app/code/server/index.ts
