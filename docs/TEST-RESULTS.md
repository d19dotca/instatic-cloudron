# Local test results

Run on 2026-08-28 on macOS arm64 with Bun `1.3.11`, Instatic `0.0.16`, Playwright `1.60.0`, Chromium `148.0.7778.96`, and Cloudron CLI `9.0.2`.

## Passed

- Official release archive SHA-256 verified.
- Cloudron package tests passed: required files, manifest/addons, immutable pins, scripts, persistence paths, 256x256 icon, 1200x400 media image, secret scan, and clean patch application.
- Current Cloudron CLI generated and verified a one-version testing `CloudronVersions.json` in a temporary copy.
- OrbStack `2.2.3` with Docker Engine `29.4.0` built the complete Cloudron `linux/amd64` image successfully on Apple silicon, including the containerized tests and production frontend build.
- An initial local build exposed a mixed-architecture image: Docker selected Bun's arm64 manifest while Cloudron's base remained amd64. The Dockerfile now pins Bun `1.3.11`'s amd64 leaf digest; the rebuilt image reports `x86_64`, and Bun executes successfully.
- Patched upstream production build completed successfully.
- Focused Bun tests passed: 60 form/database/config/mail tests, including PostgreSQL URL adapter selection and the sendmail message/header-sanitization test.
- Core browser lifecycle passed: 6/6 tests including first-run setup, owner login/logout, edit, save, publish, anonymous public render, and unpublished-draft isolation.
- Forms browser lifecycle passed: 7/7 tests including form/table authoring, publish, public submission, persisted row, mobile too-fast rejection, and accepted retry.
- Media browser lifecycle passed: 6/6 focused/dependency tests including image upload, placement, publish, and public rendering.
- Production server restart check passed with the same local SQLite data and upload roots: `/health`, the published page, and the uploaded image returned successfully before and after restart.
- The packaged image booted against disposable PostgreSQL `17.6`, created all 38 expected tables, and became Docker-health-check healthy.
- `/app/data/uploads` and `/app/data/secrets` were created. The generated secret-key checksum was unchanged across a container restart, and `/health` returned successfully afterward.

Instatic's development browser console emitted transient MCP workspace-bridge reconnect messages and a media-variant warning for the tiny test fixture; the asserted workflows still passed.

## Remaining Cloudron release gates

- A disposable Cloudron install was authorized. Cloudron Connector `0.8.0` was installed locally with a fixed-purpose, hash-bound Community App provisioning tool, but the current Codex task still has the prior MCP process loaded. Codex must reload the plugin before the new install tool can be used.
- Cloudron backup/restore, app restart, upgrade, logs, domain change, and addon credential rotation remain untested because they require that disposable installation.
- Real relay email: requires Cloudron sendmail credentials and a recipient mailbox. The local fake-sendmail integration test passed; a real message was not sent.

These remaining items are release gates in `docs/VERIFICATION.md`, not assumed successes.
