#!/bin/bash
set -euo pipefail

origin=${1:?Usage: cloudron-smoke.sh https://app.example.com}
origin=${origin%/}

health_body=$(curl -fsS --max-time 10 "${origin}/health")
printf 'Health: %s\n' "${health_body}"

admin_status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "${origin}/admin")
case "${admin_status}" in
    200|301|302) printf 'Admin route reachable: HTTP %s\n' "${admin_status}" ;;
    *) printf 'Unexpected admin status: HTTP %s\n' "${admin_status}" >&2; exit 1 ;;
esac

headers_file=$(mktemp)
trap 'rm -f "${headers_file}"' EXIT
public_status=$(curl -sS -D "${headers_file}" -o /dev/null -w '%{http_code}' --max-time 10 "${origin}/")
case "${public_status}" in
    200|404) printf 'Public route responsive: HTTP %s\n' "${public_status}" ;;
    302)
        public_location=$(awk 'tolower($1) == "location:" { sub(/\r$/, "", $2); print $2; exit }' "${headers_file}")
        case "${public_location}" in
            /admin|/admin/|"${origin}/admin"|"${origin}/admin/")
                printf 'Fresh public route redirects to admin setup: HTTP 302 -> %s\n' "${public_location}"
                ;;
            *)
                printf 'Unexpected public redirect: HTTP 302 -> %s\n' "${public_location:-<missing Location header>}" >&2
                exit 1
                ;;
        esac
        ;;
    *) printf 'Unexpected public status: HTTP %s\n' "${public_status}" >&2; exit 1 ;;
esac

printf 'Read-only Cloudron smoke checks passed\n'
