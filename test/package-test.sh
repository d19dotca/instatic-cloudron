#!/bin/bash
set -euo pipefail

package_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failures=0
manifest_version=$(jq -r .version "${package_dir}/CloudronManifest.json")
upstream_version=$(jq -r .upstreamVersion "${package_dir}/CloudronManifest.json")

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }
require_file() { [[ -f "${package_dir}/$1" ]] && pass "found $1" || fail "missing $1"; }

for file in .dockerignore .gitattributes CloudronManifest.json CloudronVersions.json Dockerfile \
    start.sh healthcheck.sh README.md SECURITY.md DESCRIPTION.md POSTINSTALL.md CHANGELOG \
    LICENSE LICENSES/Instatic-MIT.txt icon.png media/instatic-setup.png \
    test/cloudron-smoke.sh test/upstream-update-test.sh scripts/prepare-upstream-update.sh \
    .github/workflows/package.yml .github/workflows/upstream-update.yml; do
    require_file "${file}"
done

if jq -e --arg manifest_version "${manifest_version}" --arg upstream_version "${upstream_version}" '
    .manifestVersion == 2 and
    .author == "Instatic" and
    .title == "Instatic" and
    .version == $manifest_version and
    .upstreamVersion == $upstream_version and
    .httpPort == 3001 and
    .multiDomain == true and
    .healthCheckPath == "/health" and
    .configurePath == "/admin" and
    .checklist["create-owner-account"].message != null and
    .memoryLimit == 536870912 and
    (.addons | keys | sort) == ["localstorage", "postgresql"] and
    .website == "https://instatic.com" and
    .packageUrl == "https://github.com/d19dotca/instatic-cloudron" and
    .packagerName == "Dustin Dauncey (d19)" and
    .packagerUrl == "https://github.com/d19dotca" and
    (has("icon") | not) and
    .iconUrl == ("https://raw.githubusercontent.com/d19dotca/instatic-cloudron/v" + $manifest_version + "/icon.png") and
    .tags == ["hosting", "cms", "website", "website builder", "static site", "visual editor"] and
    .mediaLinks == [("https://raw.githubusercontent.com/d19dotca/instatic-cloudron/v" + $manifest_version + "/media/instatic-setup.png")]
' "${package_dir}/CloudronManifest.json" >/dev/null; then
    pass 'manifest contract'
else
    fail 'manifest contract'
fi

artifact_sha256=$(sed -n 's/^ARG INSTATIC_ARTIFACT_SHA256=//p' "${package_dir}/Dockerfile")
if rg -Fq "INSTATIC_VERSION=${upstream_version}" "${package_dir}/Dockerfile" \
    && [[ "${artifact_sha256}" =~ ^[0-9a-f]{64}$ ]] \
    && rg -q 'releases/download/v\$\{INSTATIC_VERSION\}/instatic-server-\$\{INSTATIC_VERSION\}-linux-x64\.tar\.gz' "${package_dir}/Dockerfile" \
    && rg -q 'cloudron/base:5\.1\.0@sha256:[0-9a-f]{64}' "${package_dir}/Dockerfile" \
    && ! rg -q '(^|:)latest([ @]|$)|oven/bun|archive/refs/tags' "${package_dir}/Dockerfile"; then
    pass 'official upstream artifact and Cloudron base are immutably pinned'
else
    fail 'image pinning contract'
fi

if rg -q 'CLOUDRON_POSTGRESQL_URL' "${package_dir}/start.sh" \
    && rg -q 'CLOUDRON_APP_ORIGIN' "${package_dir}/start.sh" \
    && rg -q 'CLOUDRON_ALIAS_DOMAINS' "${package_dir}/start.sh" \
    && rg -q 'TRUSTED_PROXY_CIDRS=.*CLOUDRON_PROXY_IP' "${package_dir}/start.sh" \
    && rg -q '/app/data/uploads' "${package_dir}/start.sh" \
    && rg -q '/app/data/secrets/instatic-secret-key' "${package_dir}/start.sh" \
    && rg -q 'openssl rand -hex 32' "${package_dir}/start.sh" \
    && rg -q 'gosu cloudron:cloudron /app/code/instatic-server' "${package_dir}/start.sh" \
    && ! rg -q 'CLOUDRON_MAIL_|sendmail|msmtp|/app/data/env' "${package_dir}/start.sh"; then
    pass 'runtime wiring'
else
    fail 'runtime wiring'
fi

if rg -q 'curl -fsS -o /dev/null http://127\.0\.0\.1:3001/health' "${package_dir}/healthcheck.sh"; then
    pass 'health check uses the upstream endpoint'
else
    fail 'health check contract'
fi

for script in start.sh healthcheck.sh scripts/prepare-upstream-update.sh test/package-test.sh test/cloudron-smoke.sh test/upstream-update-test.sh; do
    if bash -n "${package_dir}/${script}"; then pass "bash syntax: ${script}"; else fail "bash syntax: ${script}"; fi
done

if "${package_dir}/test/upstream-update-test.sh"; then
    pass 'upstream updater fixtures'
else
    fail 'upstream updater fixtures'
fi

if rg -Fq "[${manifest_version}]" "${package_dir}/CHANGELOG" \
    && rg -Fq "Instatic \`${upstream_version}\`" "${package_dir}/README.md" "${package_dir}/DESCRIPTION.md" \
    && rg -Fq "placeholder: ${manifest_version}" "${package_dir}/.github/ISSUE_TEMPLATE/package-bug.yml" \
    && ! rg -q '0\.0\.18' "${package_dir}/README.md" "${package_dir}/DESCRIPTION.md" "${package_dir}/POSTINSTALL.md"; then
    pass 'current package documentation'
else
    fail 'current package documentation'
fi

if jq -e '
    .stable == true and
    .versions["0.1.4"].publishState == "published" and
    .versions["0.2.0"].publishState == "published" and
    .versions["0.2.0"].manifest.dockerImage == "ghcr.io/d19dotca/instatic-cloudron:0.2.0" and
    (
      .versions["0.3.0"] == null or
      (
        .versions["0.3.0"].publishState == "published" and
        .versions["0.3.0"].manifest.upstreamVersion == "0.0.19" and
        .versions["0.3.0"].manifest.dockerImage == "ghcr.io/d19dotca/instatic-cloudron:0.3.0"
      )
    )
' "${package_dir}/CloudronVersions.json" >/dev/null; then
    pass 'published catalog history'
else
    fail 'catalog history contract'
fi

if rg -q '^  schedule:$' "${package_dir}/.github/workflows/upstream-update.yml" \
    && rg -q '^  workflow_dispatch:$' "${package_dir}/.github/workflows/upstream-update.yml" \
    && rg -q '^  contents: write$' "${package_dir}/.github/workflows/upstream-update.yml" \
    && rg -q '^  pull-requests: write$' "${package_dir}/.github/workflows/upstream-update.yml" \
    && rg -q 'docker build .*--platform linux/amd64|--platform linux/amd64' "${package_dir}/.github/workflows/upstream-update.yml" \
    && ! rg -q 'docker push|gh release create|cloudron versions add|cloudron (install|update)' "${package_dir}/.github/workflows/upstream-update.yml"; then
    pass 'upstream updater prepares and tests PRs without publishing or deploying'
else
    fail 'upstream updater safety contract'
fi

if rg -q -- '--platform linux/amd64' "${package_dir}/.github/workflows/package.yml"; then
    pass 'CI builds linux/amd64 explicitly'
else
    fail 'CI architecture contract'
fi

if file "${package_dir}/icon.png" | rg -q 'PNG image data, 256 x 256' \
    && file "${package_dir}/media/instatic-setup.png" | rg -q 'PNG image data, 1200 x 400'; then
    pass 'Community App media dimensions'
else
    fail 'Community App media dimensions'
fi

secret_findings=$(rg -n --hidden -g '!.git/**' -g '!test/package-test.sh' -- \
    "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|password)\\s*[:=]\\s*['\\\"][A-Za-z0-9+/=_-]{20,}" \
    "${package_dir}" || true)
if [[ -z "${secret_findings}" ]]; then
    pass 'no obvious committed credentials or private keys'
else
    printf '%s\n' "${secret_findings}" >&2
    fail 'possible committed secret'
fi

if (( failures > 0 )); then
    printf '%d package test(s) failed\n' "${failures}" >&2
    exit 1
fi

printf 'All package tests passed.\n'
