#!/bin/bash
set -euo pipefail

package_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "${test_dir}"' EXIT

fixture_package="${test_dir}/package"
mkdir -p "${fixture_package}"
cp -R "${package_dir}/." "${fixture_package}/"

current_upstream=$(jq -r .upstreamVersion "${fixture_package}/CloudronManifest.json")
current_package=$(jq -r .version "${fixture_package}/CloudronManifest.json")
IFS=. read -r upstream_major upstream_minor upstream_patch <<< "${current_upstream}"
IFS=. read -r package_major package_minor package_patch <<< "${current_package}"
next_upstream="${upstream_major}.${upstream_minor}.$((upstream_patch + 1))"
next_package="${package_major}.${package_minor}.$((package_patch + 1))"
artifact_name="instatic-server-${next_upstream}-linux-x64.tar.gz"
checksums_name="instatic-server-${next_upstream}-checksums.txt"
fixture_sha256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

checksums_path="${test_dir}/${checksums_name}"
printf '%s  %s\n' "${fixture_sha256}" "${artifact_name}" > "${checksums_path}"

release_path="${test_dir}/release.json"
jq -n \
    --arg tag "v${next_upstream}" \
    --arg release_url "https://example.invalid/releases/v${next_upstream}" \
    --arg artifact_name "${artifact_name}" \
    --arg artifact_url "file://${test_dir}/${artifact_name}" \
    --arg checksums_name "${checksums_name}" \
    --arg checksums_url "file://${checksums_path}" \
    '{
      tag_name: $tag,
      html_url: $release_url,
      draft: false,
      prerelease: false,
      assets: [
        {name: $artifact_name, browser_download_url: $artifact_url},
        {name: $checksums_name, browser_download_url: $checksums_url}
      ]
    }' > "${release_path}"

catalog_before=$(sha256sum "${fixture_package}/CloudronVersions.json" | awk '{print $1}')
INSTATIC_RELEASE_API_URL="file://${release_path}" "${fixture_package}/scripts/prepare-upstream-update.sh"

jq -e \
    --arg package "${next_package}" \
    --arg upstream "${next_upstream}" \
    '.version == $package and .upstreamVersion == $upstream' \
    "${fixture_package}/CloudronManifest.json" >/dev/null
rg -Fq "INSTATIC_VERSION=${next_upstream}" "${fixture_package}/Dockerfile"
rg -Fq "INSTATIC_ARTIFACT_SHA256=${fixture_sha256}" "${fixture_package}/Dockerfile"
rg -Fq "[${next_package}]" "${fixture_package}/CHANGELOG"
rg -Fq "Instatic \`${next_upstream}\`" "${fixture_package}/README.md" "${fixture_package}/DESCRIPTION.md"
rg -Fq "placeholder: ${next_package}" "${fixture_package}/.github/ISSUE_TEMPLATE/package-bug.yml"

catalog_after=$(sha256sum "${fixture_package}/CloudronVersions.json" | awk '{print $1}')
if [[ "${catalog_before}" != "${catalog_after}" ]]; then
    printf 'Updater modified immutable catalog history.\n' >&2
    exit 1
fi

tree_before=$(find "${fixture_package}" -type f -not -path '*/.git/*' -exec sha256sum {} + | sort | sha256sum | awk '{print $1}')
INSTATIC_RELEASE_API_URL="file://${release_path}" "${fixture_package}/scripts/prepare-upstream-update.sh"
tree_after=$(find "${fixture_package}" -type f -not -path '*/.git/*' -exec sha256sum {} + | sort | sha256sum | awk '{print $1}')
if [[ "${tree_before}" != "${tree_after}" ]]; then
    printf 'Updater was not idempotent when the release was already packaged.\n' >&2
    exit 1
fi

jq '.draft = true' "${release_path}" > "${test_dir}/draft-release.json"
if INSTATIC_RELEASE_API_URL="file://${test_dir}/draft-release.json" \
    "${fixture_package}/scripts/prepare-upstream-update.sh" >/dev/null 2>&1; then
    printf 'Updater accepted a draft release.\n' >&2
    exit 1
fi

printf 'Upstream updater fixture tests passed.\n'
