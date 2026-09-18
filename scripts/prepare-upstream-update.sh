#!/bin/bash
set -euo pipefail

package_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest_path="${package_dir}/CloudronManifest.json"
dockerfile_path="${package_dir}/Dockerfile"
release_api_url=${INSTATIC_RELEASE_API_URL:-https://api.github.com/repos/CoreBunch/Instatic/releases/latest}

for command in curl jq python3; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "${command}" >&2
        exit 1
    fi
done

work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT

release_json="${work_dir}/release.json"
checksums_file="${work_dir}/checksums.txt"

curl -fsSL --retry 5 --retry-all-errors "${release_api_url}" -o "${release_json}"

if ! jq -e '.draft == false and .prerelease == false' "${release_json}" >/dev/null; then
    printf 'Latest GitHub release is a draft or prerelease; refusing to update.\n' >&2
    exit 1
fi

release_tag=$(jq -r '.tag_name' "${release_json}")
latest_upstream_version=${release_tag#v}
current_upstream_version=$(jq -r '.upstreamVersion' "${manifest_path}")
current_package_version=$(jq -r '.version' "${manifest_path}")

semver_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'
for version in "${latest_upstream_version}" "${current_upstream_version}" "${current_package_version}"; do
    if [[ ! "${version}" =~ ${semver_pattern} ]]; then
        printf 'Unsupported version format: %s\n' "${version}" >&2
        exit 1
    fi
done

if [[ "${latest_upstream_version}" == "${current_upstream_version}" ]]; then
    printf 'Instatic %s is already packaged.\n' "${latest_upstream_version}"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf 'changed=false\n' >> "${GITHUB_OUTPUT}"
    fi
    exit 0
fi

version_key() {
    local major minor patch
    IFS=. read -r major minor patch <<< "$1"
    printf '%09d%09d%09d' "${major}" "${minor}" "${patch}"
}

if [[ "$(version_key "${latest_upstream_version}")" < "$(version_key "${current_upstream_version}")" ]]; then
    printf 'Latest stable release %s is older than packaged release %s; refusing to downgrade.\n' \
        "${latest_upstream_version}" "${current_upstream_version}" >&2
    exit 1
fi

artifact_name="instatic-server-${latest_upstream_version}-linux-x64.tar.gz"
checksums_name="instatic-server-${latest_upstream_version}-checksums.txt"
artifact_url=$(jq -r --arg name "${artifact_name}" '.assets[] | select(.name == $name) | .browser_download_url' "${release_json}" | head -n 1)
checksums_url=$(jq -r --arg name "${checksums_name}" '.assets[] | select(.name == $name) | .browser_download_url' "${release_json}" | head -n 1)

if [[ -z "${artifact_url}" || -z "${checksums_url}" ]]; then
    printf 'Release %s does not contain the required Linux artifact and checksum list.\n' "${release_tag}" >&2
    exit 1
fi

curl -fsSL --retry 5 --retry-all-errors "${checksums_url}" -o "${checksums_file}"
artifact_sha256=$(awk -v artifact="${artifact_name}" '$2 == artifact { print $1 }' "${checksums_file}")

if [[ ! "${artifact_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'No valid SHA-256 was found for %s.\n' "${artifact_name}" >&2
    exit 1
fi

IFS=. read -r package_major package_minor package_patch <<< "${current_package_version}"
next_package_version="${package_major}.${package_minor}.$((package_patch + 1))"
release_url=$(jq -r '.html_url' "${release_json}")

python3 - \
    "${package_dir}" \
    "${current_upstream_version}" \
    "${latest_upstream_version}" \
    "${current_package_version}" \
    "${next_package_version}" \
    "${artifact_sha256}" \
    "${release_url}" <<'PY'
import json
import pathlib
import re
import sys

(
    package_dir_raw,
    current_upstream,
    latest_upstream,
    current_package,
    next_package,
    artifact_sha256,
    release_url,
) = sys.argv[1:]
package_dir = pathlib.Path(package_dir_raw)

manifest_path = package_dir / "CloudronManifest.json"
manifest = json.loads(manifest_path.read_text())
manifest["version"] = next_package
manifest["upstreamVersion"] = latest_upstream
manifest["iconUrl"] = f"https://raw.githubusercontent.com/d19dotca/instatic-cloudron/v{next_package}/icon.png"
manifest["mediaLinks"] = [
    f"https://raw.githubusercontent.com/d19dotca/instatic-cloudron/v{next_package}/media/instatic-setup.png"
]
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

dockerfile_path = package_dir / "Dockerfile"
dockerfile = dockerfile_path.read_text()
dockerfile, version_count = re.subn(
    r"^ARG INSTATIC_VERSION=.*$",
    f"ARG INSTATIC_VERSION={latest_upstream}",
    dockerfile,
    count=1,
    flags=re.MULTILINE,
)
dockerfile, checksum_count = re.subn(
    r"^ARG INSTATIC_ARTIFACT_SHA256=[0-9a-f]{64}$",
    f"ARG INSTATIC_ARTIFACT_SHA256={artifact_sha256}",
    dockerfile,
    count=1,
    flags=re.MULTILINE,
)
if version_count != 1 or checksum_count != 1:
    raise SystemExit("Could not update the Docker artifact pins exactly once")
dockerfile_path.write_text(dockerfile)

for relative_path in ("README.md", "DESCRIPTION.md"):
    path = package_dir / relative_path
    text = path.read_text()
    old = f"Instatic `{current_upstream}`"
    new = f"Instatic `{latest_upstream}`"
    if old not in text:
        raise SystemExit(f"Expected version text not found in {relative_path}: {old}")
    path.write_text(text.replace(old, new))

issue_template_path = package_dir / ".github" / "ISSUE_TEMPLATE" / "package-bug.yml"
issue_template = issue_template_path.read_text()
old_placeholder = f"placeholder: {current_package}"
new_placeholder = f"placeholder: {next_package}"
if old_placeholder not in issue_template:
    raise SystemExit(f"Expected package-version placeholder not found: {old_placeholder}")
issue_template_path.write_text(issue_template.replace(old_placeholder, new_placeholder, 1))

changelog_path = package_dir / "CHANGELOG"
changelog = changelog_path.read_text()
heading = f"[{next_package}]"
if heading not in changelog:
    entry = (
        f"{heading}\n"
        f"* Update Instatic from {current_upstream} to {latest_upstream}.\n"
        f"* Verify the official Linux x64 artifact with SHA-256 `{artifact_sha256}`.\n"
        f"* Upstream release: {release_url}\n\n"
    )
    changelog_path.write_text(entry + changelog)
PY

printf 'Prepared package %s for Instatic %s (%s).\n' \
    "${next_package_version}" "${latest_upstream_version}" "${artifact_sha256}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        printf 'changed=true\n'
        printf 'upstream_version=%s\n' "${latest_upstream_version}"
        printf 'package_version=%s\n' "${next_package_version}"
        printf 'release_url=%s\n' "${release_url}"
    } >> "${GITHUB_OUTPUT}"
fi
