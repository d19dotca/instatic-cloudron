#!/bin/bash
set -euo pipefail

package_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=${1:-}
failures=0
manifest_version=$(jq -r .version "${package_dir}/CloudronManifest.json")

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }
require_file() { [[ -f "${package_dir}/$1" ]] && pass "found $1" || fail "missing $1"; }

for file in .dockerignore .gitattributes CloudronManifest.json CloudronVersions.json Dockerfile start.sh healthcheck.sh icon.png media/instatic-setup.png \
    README.md SECURITY.md DESCRIPTION.md POSTINSTALL.md CHANGELOG LICENSE LICENSES/Instatic-MIT.txt \
    docs/ARCHITECTURE.md docs/TESTING.md docs/UPSTREAM.md; do
    require_file "${file}"
done

if jq -e --arg manifest_version "${manifest_version}" '
    .manifestVersion == 2 and
    .author == "Dustin Dauncey <dustin@d19.ca>" and
    .title == "Instatic" and
    .version == $manifest_version and
    .upstreamVersion == "0.0.17" and
    .httpPort == 3001 and
    .healthCheckPath == "/health" and
    .configurePath == "/admin" and
    .checklist["create-owner-account"].message != null and
    .memoryLimit == 536870912 and
    (.addons.localstorage | type == "object") and
    (.addons.postgresql | type == "object") and
    (.addons | keys | sort) == ["localstorage", "postgresql"] and
    .packageUrl == "https://github.com/d19dotca/instatic-cloudron" and
    .icon == "file://icon.png" and
    .iconUrl == ("https://raw.githubusercontent.com/d19dotca/instatic-cloudron/v" + $manifest_version + "/icon.png") and
    .tags == ["hosting"] and
    (.mediaLinks | length == 1)
' "${package_dir}/CloudronManifest.json" >/dev/null; then
    pass 'manifest contract'
else
    fail 'manifest contract'
fi

if ! rg -q -i 'Cloudron outbound email|provides[^.]*email notifications?|form notifications default' "${package_dir}/DESCRIPTION.md" \
    && rg -q 'does not send form-submission email notifications' "${package_dir}/DESCRIPTION.md"; then
    pass 'Community App description matches upstream-only form behavior'
else
    fail 'Community App description must not promise form email delivery'
fi

if rg -q "^\\[${manifest_version//./\\.}\\]$" "${package_dir}/CHANGELOG"; then
    pass 'manifest version has a changelog section'
else
    fail 'manifest version must have a changelog section'
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

if ! rg -q 'src/__tests__/server/formMail\.test\.ts' "${package_dir}/Dockerfile" \
    && rg -q 'src/__tests__/server/router\.test\.ts' "${package_dir}/Dockerfile" \
    && rg -q 'src/__tests__/forms/formSnapshot\.test\.ts' "${package_dir}/Dockerfile" \
    && rg -q 'src/__tests__/forms/formModules\.test\.ts' "${package_dir}/Dockerfile" \
    && rg -q 'src/__tests__/panels/formSettingsPanel\.test\.tsx' "${package_dir}/Dockerfile"; then
    pass 'container build runs upstream form, editor UI, and public-output tests without mail patch coverage'
else
    fail 'container build must run upstream form tests without downstream mail tests'
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

for script in start.sh healthcheck.sh test/package-test.sh test/cloudron-smoke.sh scripts/verify-upstream.sh; do
    if bash -n "${package_dir}/${script}"; then pass "bash syntax: ${script}"; else fail "bash syntax: ${script}"; fi
done

if rg -q '/app/data/uploads' "${package_dir}/start.sh" \
    && rg -q '/app/data/secrets/instatic-secret-key' "${package_dir}/start.sh" \
    && rg -q 'openssl rand -hex 32' "${package_dir}/start.sh" \
    && rg -q 'CLOUDRON_POSTGRESQL_URL' "${package_dir}/start.sh" \
    && rg -q 'CLOUDRON_APP_ORIGIN' "${package_dir}/start.sh" \
    && ! rg -q 'CLOUDRON_MAIL_|INSTATIC_.*MAIL|msmtp|sendmail' "${package_dir}/start.sh" \
    && ! rg -q 'COPY patches/|/tmp/patches|msmtp|sendmail|INSTATIC_SENDMAIL' "${package_dir}/Dockerfile" \
    && [[ ! -e "${package_dir}/patches/0001-cloudron-form-email.patch" ]]; then
    pass 'runtime persistence, database, and domain wiring without downstream mail integration'
else
    fail 'runtime wiring'
fi

if file "${package_dir}/icon.png" | rg -q 'PNG image data, 256 x 256'; then
    pass '256x256 PNG icon'
else
    fail 'icon.png must be a 256x256 PNG'
fi

if python3 - "${package_dir}/icon.png" <<'PY'
import struct
import sys
import zlib

data = open(sys.argv[1], "rb").read()
offset = 8
idat = []
width = height = bit_depth = color_type = None
while offset < len(data):
    size = struct.unpack(">I", data[offset:offset + 4])[0]
    chunk_type = data[offset + 4:offset + 8]
    chunk = data[offset + 8:offset + 8 + size]
    offset += size + 12
    if chunk_type == b"IHDR":
        width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk)
    elif chunk_type == b"IDAT":
        idat.append(chunk)
    elif chunk_type == b"IEND":
        break

if (width, height, bit_depth, color_type) != (256, 256, 8, 6):
    raise SystemExit(1)

raw = zlib.decompress(b"".join(idat))
stride = width * 4
previous = bytearray(stride)
rows = []
offset = 0
for _ in range(height):
    filter_type = raw[offset]
    offset += 1
    scanline = bytearray(raw[offset:offset + stride])
    offset += stride
    for index in range(stride):
        left = scanline[index - 4] if index >= 4 else 0
        above = previous[index]
        upper_left = previous[index - 4] if index >= 4 else 0
        if filter_type == 1:
            scanline[index] = (scanline[index] + left) & 255
        elif filter_type == 2:
            scanline[index] = (scanline[index] + above) & 255
        elif filter_type == 3:
            scanline[index] = (scanline[index] + ((left + above) // 2)) & 255
        elif filter_type == 4:
            estimate = left + above - upper_left
            distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
            predictor = (left, above, upper_left)[distances.index(min(distances))]
            scanline[index] = (scanline[index] + predictor) & 255
        elif filter_type != 0:
            raise SystemExit(1)
    rows.append(scanline)
    previous = scanline

dark = [
    (x, y)
    for y, row in enumerate(rows)
    for x in range(width)
    if row[x * 4 + 3] > 16 and max(row[x * 4:x * 4 + 3]) < 128
]
if not dark:
    raise SystemExit(1)

xs = [point[0] for point in dark]
ys = [point[1] for point in dark]
left, right = min(xs), width - 1 - max(xs)
top, bottom = min(ys), height - 1 - max(ys)
corner_pixels = [rows[y][x * 4:x * 4 + 4] for x, y in ((0, 0), (255, 0), (0, 255), (255, 255))]
if left != 0 or right != 0 or top != 0 or bottom != 0:
    raise SystemExit(1)
if any(max(pixel[:3]) >= 16 or pixel[3] < 240 for pixel in corner_pixels):
    raise SystemExit(1)
PY
then
    pass 'canonical icon artwork is centered and retains all four corner dots'
else
    fail 'icon artwork must be centered and retain the canonical four corner dots'
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
    elif "${package_dir}/scripts/verify-upstream.sh" "${source_dir}"; then
        pass 'unmodified supplied upstream contract'
    else
        fail 'supplied upstream contract validation'
    fi
fi

if (( failures > 0 )); then
    printf '%d package test(s) failed\n' "${failures}" >&2
    exit 1
fi
printf 'All package tests passed\n'
