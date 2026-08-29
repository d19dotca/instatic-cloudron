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
- Docker Hub and the current Cloudron packaging guide were rechecked on 2026-08-28. The package already uses the recommended `cloudron/base:5.1.0` digest `sha256:1c0666c9abe9e2090d33686826d4e97769b799124573118d41e0d7485135748e`.
- Cloudron `10.0.2` installed the package at the disposable test location after updating the local Cloudron CLI from `8.2.4` to `9.0.2`. Independent API readback showed installation state `installed`, run state `running`, and health `healthy`.
- Cloudron restart task `36613` completed successfully. Subsequent app readback was healthy, and logs showed graceful SIGTERM handling followed by a clean PostgreSQL-backed startup.
- Cloudron backup task `36614` completed successfully and exactly one new encrypted app backup was verified in the configured backup site.
- First-run setup completed with a disposable administrator and no package-supplied credentials.
- Live authoring and publication passed: a test page was published, returned HTTP 200 anonymously, and rendered as compact generated HTML.
- Live upload persistence passed: the package icon was uploaded, published, and its public SHA-256 matched the source file exactly before and after restart.
- The administration route remained protected from an anonymous client and returned only the sign-in shell, while the public page remained anonymously available.
- Populated-state restart task `36617` completed successfully; PostgreSQL-backed content, the public page, health endpoint, and uploaded file all survived.
- Populated-state backup task `36618` completed successfully and exactly one new encrypted app backup was verified.
- The private form-recipient override was stored under `/app/data/env`, verified by hash without exposing its contents, and survived restart task `36619`; app readback afterward was `running` and `healthy`.
- A CMS-native form backed by a PostgreSQL table was authored and published. Its public input and submit control are visible and enabled; the final real-mail submission is awaiting action-time confirmation.

Instatic's development browser console emitted transient MCP workspace-bridge reconnect messages and a media-variant warning for the tiny test fixture; the asserted workflows still passed.

## Remaining Cloudron release gates

- The first guarded Cloudron install attempt was rejected before provisioning because `packageUrl` is not an allowed Cloudron manifest property. It was removed and a regression assertion was added before retrying.
- Cloudron restore is intentionally unavailable through the guarded connector, so the verified encrypted backup has not been destructively restored.
- Package upgrade and primary-domain change are not exposed with a complete verifier through the guarded connector and remain untested live. Startup derives `PUBLIC_ORIGIN` from Cloudron on every boot, and both paths remain release-matrix checks.
- Addon credential rotation remains untested live.
- Real relay email: the live form is published and prepared, but the actual submission and message send await the required action-time confirmation. The local fake-sendmail integration test passed.

These remaining items are release gates in `docs/VERIFICATION.md`, not assumed successes.
