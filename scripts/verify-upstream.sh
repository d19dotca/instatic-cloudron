#!/bin/bash
set -euo pipefail

source_dir=${1:?Usage: verify-upstream.sh /path/to/Instatic-source}
package_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
expected_version=$(jq -r .upstreamVersion "${package_dir}/CloudronManifest.json")
actual_version=$(jq -r .version "${source_dir}/package.json")

[[ "${actual_version}" == "${expected_version}" ]] || {
    printf 'Expected upstream %s, got %s\n' "${expected_version}" "${actual_version}" >&2
    exit 1
}

for path in LICENSE Dockerfile server/config.ts server/healthcheck.ts server/forms/handler.ts docs/deployment/README.md docs/deployment/backup-restore.md docs/features/auth-and-access.md docs/features/cms-native-forms.md docs/reference/database-dialects.md; do
    [[ -f "${source_dir}/${path}" ]] || { printf 'Missing upstream contract file: %s\n' "${path}" >&2; exit 1; }
done

rg -q "pathname === '/health'|/health" "${source_dir}/server" || { printf 'Health route contract missing\n' >&2; exit 1; }
rg -q 'postgres://|postgresql://' "${source_dir}/server/db" || { printf 'PostgreSQL adapter contract missing\n' >&2; exit 1; }
rg -q 'published/current' "${source_dir}" || { printf 'Published artifact contract missing\n' >&2; exit 1; }
patch --dry-run --silent -d "${source_dir}" -p1 < "${package_dir}/patches/0001-cloudron-form-email.patch"

printf 'Upstream %s contract and patch applicability verified\n' "${actual_version}"
