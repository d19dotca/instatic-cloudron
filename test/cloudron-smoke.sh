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

public_status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "${origin}/")
case "${public_status}" in
    200|404) printf 'Public route responsive: HTTP %s\n' "${public_status}" ;;
    *) printf 'Unexpected public status: HTTP %s\n' "${public_status}" >&2; exit 1 ;;
esac

printf 'Read-only Cloudron smoke checks passed\n'
