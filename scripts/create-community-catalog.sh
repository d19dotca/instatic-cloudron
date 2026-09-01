#!/bin/bash
set -euo pipefail

image=${1:?Usage: create-community-catalog.sh registry.example.com/instatic-cloudron:0.1.4}
package_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${package_dir}"

[[ "${image}" == *:* ]] || { printf 'Use an immutable versioned image tag, not an untagged image\n' >&2; exit 1; }
[[ "${image}" != *:latest ]] || { printf 'Refusing latest tag\n' >&2; exit 1; }
[[ ! -e CloudronVersions.json ]] || { printf 'CloudronVersions.json already exists; update it with the Cloudron CLI\n' >&2; exit 1; }

cloudron versions init
cloudron versions add --image "${image}" --state testing
cloudron versions verify

printf 'Created a testing catalog. Review CloudronVersions.json before hosting or publishing it.\n'
