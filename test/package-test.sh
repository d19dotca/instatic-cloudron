#!/bin/bash
set -euo pipefail

package_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=${1:-}
failures=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }
require_file() { [[ -f "${package_dir}/$1" ]] && pass "found $1" || fail "missing $1"; }

for file in .dockerignore CloudronManifest.json CloudronVersions.json Dockerfile start.sh healthcheck.sh icon.svg icon.png media/instatic-setup.png \
    README.md SECURITY.md DESCRIPTION.md POSTINSTALL.md CHANGELOG LICENSE LICENSES/Instatic-MIT.txt \
    patches/0001-cloudron-form-email.patch docs/ARCHITECTURE.md docs/REFERENCES.md docs/TESTING.md docs/UPSTREAM.md; do
    require_file "${file}"
done

if jq -e '
    .manifestVersion == 2 and
    .author == "Dustin Dauncey <dustin@d19.ca>" and
    .contactEmail == "dustin@d19.ca" and
    .version == "0.1.4" and
    .upstreamVersion == "0.0.17" and
    .httpPort == 3001 and
    .healthCheckPath == "/health" and
    .configurePath == "/admin" and
    .memoryLimit == 536870912 and
    (.addons.localstorage | type == "object") and
    (.addons.postgresql | type == "object") and
    (.addons.sendmail | type == "object") and
    .packageUrl == "https://github.com/d19dotca/instatic-cloudron" and
    (.icon == "file://icon.png") and
    (.mediaLinks | length == 1)
' "${package_dir}/CloudronManifest.json" >/dev/null; then
    pass 'manifest contract'
else
    fail 'manifest contract'
fi

if jq -e '
    .stable == true and
    .versions["0.1.4"].publishState == "published" and
    .versions["0.1.4"].manifest.dockerImage == "ghcr.io/d19dotca/instatic-cloudron:0.1.4" and
    .versions["0.1.4"].manifest.memoryLimit == 536870912
' "${package_dir}/CloudronVersions.json" >/dev/null; then
    pass 'published community catalog contract'
else
    fail 'published community catalog contract'
fi

if ! rg -n '^\s*set\s+-[^#]*x|^\s*(printenv|env)(\s|$)' "${package_dir}/start.sh" >/dev/null; then
    pass 'startup script does not enable tracing or dump the environment'
else
    fail 'startup script must not trace commands or dump the environment'
fi

if rg -q 'cloudron/base:5\.1\.0@sha256:[0-9a-f]{64}' "${package_dir}/Dockerfile" \
    && rg -q 'oven/bun:1\.3\.11@sha256:[0-9a-f]{64}' "${package_dir}/Dockerfile" \
    && ! rg -n '(^|:)latest([ @]|$)' "${package_dir}/Dockerfile" >/dev/null; then
    pass 'base images are immutable and no latest tag is used'
else
    fail 'base image pinning'
fi

if rg -q 'INSTATIC_VERSION=0\.0\.17' "${package_dir}/Dockerfile" \
    && rg -q 'INSTATIC_ARCHIVE_SHA256=53a9ca19f798db7459d81ca96c15d1fe9000a970bde6f544adf660b292ee5bae' "${package_dir}/Dockerfile"; then
    pass 'upstream release and archive checksum are pinned'
else
    fail 'upstream release pin'
fi

if rg -q 'src/__tests__/server/formMail\.test\.ts' "${package_dir}/Dockerfile"; then
    pass 'container build runs the mail integration test'
else
    fail 'container build must run the mail integration test'
fi

if ! rg -q -- '--mount=type=cache' "${package_dir}/Dockerfile" \
    && ! rg -q -- 'COPY .*--chmod' "${package_dir}/Dockerfile" \
    && rg -q -- 'COPY --chown=cloudron:cloudron' "${package_dir}/Dockerfile" \
    && rg -q -- 'FROM source AS runtime-source' "${package_dir}/Dockerfile"; then
    pass 'Cloudron-compatible dependency layering and runtime optimization'
else
    fail 'container optimization contract'
fi

if rg -q 'org\.opencontainers\.image\.source="https://github\.com/d19dotca/instatic-cloudron"' "${package_dir}/Dockerfile"; then
    pass 'GHCR source linkage label'
else
    fail 'GHCR source linkage label'
fi

for script in start.sh healthcheck.sh test/package-test.sh test/cloudron-smoke.sh scripts/verify-upstream.sh scripts/create-community-catalog.sh; do
    if bash -n "${package_dir}/${script}"; then pass "bash syntax: ${script}"; else fail "bash syntax: ${script}"; fi
done

if rg -q '/app/data/uploads' "${package_dir}/start.sh" \
    && rg -q '/app/data/secrets/instatic-secret-key' "${package_dir}/start.sh" \
    && rg -q 'CLOUDRON_POSTGRESQL_URL' "${package_dir}/start.sh" \
    && rg -q 'CLOUDRON_APP_ORIGIN' "${package_dir}/start.sh" \
    && rg -q 'CLOUDRON_MAIL_SMTP_SERVER' "${package_dir}/start.sh" \
    && rg -q 'INSTATIC_MSMTP_CONFIG=/run/instatic/msmtprc' "${package_dir}/start.sh" \
    && rg -q 'auth plain' "${package_dir}/start.sh" \
    && rg -q "'\\-C', configPath" "${package_dir}/patches/0001-cloudron-form-email.patch"; then
    pass 'runtime persistence, database, domain, and mail wiring'
else
    fail 'runtime wiring'
fi

if file "${package_dir}/icon.png" | rg -q 'PNG image data, 256 x 256'; then
    pass '256x256 PNG icon'
else
    fail 'icon.png must be a 256x256 PNG'
fi

if file "${package_dir}/media/instatic-setup.png" | rg -q 'PNG image data, 1200 x 400'; then
    pass '1200x400 Community App screenshot'
else
    fail 'Community App screenshot must be a 1200x400 PNG'
fi

secret_findings=$(rg -n --hidden \
    -g '!.git/**' -g '!test/package-test.sh' \
    -- \
    "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|password)\\s*[:=]\\s*['\\\"][A-Za-z0-9+/=_-]{20,}" \
    "${package_dir}" || true)
if [[ -z "${secret_findings}" ]]; then
    pass 'no obvious committed credentials or private keys'
else
    printf '%s\n' "${secret_findings}" >&2
    fail 'possible committed secret'
fi

if [[ -n "${source_dir}" ]]; then
    if [[ ! -d "${source_dir}/server/forms" ]]; then
        fail "invalid upstream source directory: ${source_dir}"
    elif patch --dry-run --silent -d "${source_dir}" -p1 < "${package_dir}/patches/0001-cloudron-form-email.patch"; then
        pass 'mail patch applies cleanly to supplied upstream source'
    else
        fail 'mail patch does not apply cleanly to supplied upstream source'
    fi
fi

if (( failures > 0 )); then
    printf '%d package test(s) failed\n' "${failures}" >&2
    exit 1
fi
printf 'All package tests passed\n'
