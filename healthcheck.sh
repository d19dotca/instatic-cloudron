#!/bin/bash
set -euo pipefail
exec /usr/local/bin/bun /app/code/server/healthcheck.ts
