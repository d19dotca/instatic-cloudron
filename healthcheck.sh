#!/bin/bash
set -euo pipefail
exec curl -fsS -o /dev/null http://127.0.0.1:3001/health
