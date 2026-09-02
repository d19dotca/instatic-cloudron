#!/bin/bash
set -euo pipefail

umask 077
mkdir -p /app/data/uploads /app/data/secrets /run/instatic
chown -R cloudron:cloudron /app/data /run/instatic
chmod 0700 /app/data/secrets

secret_file=/app/data/secrets/instatic-secret-key
if [[ -e "${secret_file}" ]]; then
    if ! grep -Eq '^[0-9a-f]{64}$' "${secret_file}"; then
        echo "Persisted Instatic secret key is malformed; refusing to replace it" >&2
        exit 1
    fi
else
    secret_tmp=$(mktemp "${secret_file}.tmp.XXXXXX")
    trap 'rm -f "${secret_tmp}"' EXIT
    openssl rand -hex 32 > "${secret_tmp}"
    if ! grep -Eq '^[0-9a-f]{64}$' "${secret_tmp}"; then
        echo "Generated Instatic secret key is malformed" >&2
        exit 1
    fi
    chown cloudron:cloudron "${secret_tmp}"
    chmod 0600 "${secret_tmp}"
    mv "${secret_tmp}" "${secret_file}"
    trap - EXIT
fi
chown cloudron:cloudron "${secret_file}"
chmod 0600 "${secret_file}"

: "${CLOUDRON_POSTGRESQL_URL:?Cloudron PostgreSQL addon is not configured}"
: "${CLOUDRON_APP_ORIGIN:?Cloudron app origin is not configured}"
: "${CLOUDRON_PROXY_IP:?Cloudron reverse proxy address is not configured}"

public_origins=${CLOUDRON_APP_ORIGIN}
IFS=',' read -ra alias_domains <<< "${CLOUDRON_ALIAS_DOMAINS:-}"
for alias_domain in "${alias_domains[@]}"; do
    alias_domain=${alias_domain//[[:space:]]/}
    [[ -n "${alias_domain}" ]] && public_origins+=",https://${alias_domain}"
done

export DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
export PUBLIC_ORIGIN="${PUBLIC_ORIGIN:-${public_origins}}"
export TRUSTED_PROXY_CIDRS="${TRUSTED_PROXY_CIDRS:-${CLOUDRON_PROXY_IP}}"
export INSTATIC_SECRET_KEY
INSTATIC_SECRET_KEY=$(<"${secret_file}")
export UPLOADS_DIR=/app/data/uploads
export STATIC_DIR=/app/code/dist
export PORT=3001

echo "Starting Instatic with PostgreSQL and persistent uploads at /app/data/uploads"
exec /usr/local/bin/gosu cloudron:cloudron /usr/local/bin/bun run /app/code/server/index.ts
