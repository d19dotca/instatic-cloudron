# Local test results

Run on 2026-08-28 through 2026-09-01 on macOS arm64 with Bun `1.3.11`, Instatic `0.0.16` and `0.0.17`, Playwright `1.60.0`, Chromium `148.0.7778.96`, and Cloudron CLI `9.0.2`.

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
- A CMS-native form backed by a PostgreSQL table was authored and published. Its public input was explicitly bound to the required table field, and one live submission persisted exactly one row.
- Live email testing exposed and documented two packaging defects without losing form data: 0.1.0 did not pass the generated msmtp configuration; 0.1.1 passed it but left authentication on automatic selection. Version 0.1.2 passes the configuration explicitly and forces PLAIN authentication for Cloudron's trusted internal non-TLS relay.
- A clean 0.1.2 instance installed at a disposable hostname, completed first-run setup, published the bound form, persisted exactly one PostgreSQL row, handed the notification to Cloudron without an application mail error, and the approved private recipient confirmed delivery.
- The populated 0.1.2 instance remained healthy after restart. Its public page, administrator session, published page record, custom table, and submitted row remained available.
- Populated-state backup task `36631` completed successfully and verified one new encrypted 0.1.2 app backup at the configured IDrive e2 backup site.
- The 0.0.17 release archive checksum, package tests, focused upstream tests, and a clean `linux/amd64` image build passed for package 0.1.3.
- Populated-instance restore, repeat upgrade, move to a temporary domain, inverse move, and a form persistence/mail check after each operation passed. See `docs/ACCEPTANCE-0.1.3.md` for task, backup, and row evidence.
- The current app-runtime log contained no credential-pattern findings. A supplied Cloudron lifecycle log disclosed live PostgreSQL and sendmail addon values in platform-generated `services: Setting ... addon config` entries; the package startup script did not emit them.
- Cloudron repair and same-backup restore both preserved PostgreSQL and sendmail credentials. The app remained healthy and forms continued to persist and deliver, but actual credential rotation is not verified.
- A separate clean package 0.1.3 instance installed at `instatic4.d19.ca` in approximately 17 seconds end to end, reached its first healthy readback approximately 8 seconds after Cloudron's creation timestamp, and restarted in 2 seconds by Cloudron task timestamps. Its runtime began listening within one-second log resolution, its fresh PostgreSQL schema contained all 38 tables and 24 migrations, and its app-runtime log had zero secret-pattern findings.
- A controlled no-cache `linux/amd64` image build took 186.52 seconds on Apple silicon. `bun run build` accounted for 127.0 seconds (approximately 81 seconds for TypeScript and 45.57 seconds for Vite); image export/unpack took 8.4 seconds. A warm-cache rebuild took 2.21 seconds, confirming that build/cache state rather than Instatic runtime startup caused most of the observed delay.
- Package 0.1.4 lowers the declared Cloudron baseline to 512 MiB. The prior constrained production-image test had already booted, migrated PostgreSQL, served `/health` and `/admin`, and completed 500 bounded admin requests at a 256 MiB limit without an OOM or restart, using approximately 141 MiB idle and 182 MiB after load. The lower 256 MiB value is not claimed as supported; 1 GiB remains advisable for heavier publishing, plugins, image work, or concurrent editors.
- Package 0.1.4 also makes dependency installation cacheable by package/lock/vendor content across upstream source changes, assigns runtime ownership with `COPY --chown`, and removes 725 upstream test-source files only after the build-stage tests pass. The completed amd64 image retained the executable startup scripts, Cloudron ownership, and Bun 1.3.11 runtime. Docker's image inspection size fell from 965,595,084 bytes for 0.1.3 to 918,046,378 bytes for 0.1.4: 47,548,706 bytes (approximately 45.3 MiB or 4.9%) smaller. The final warm-cache rebuild took 2.26 seconds.
- The optimized rebuild still spent approximately 115 seconds in `bun run build` and 150.27 seconds overall when refreshed source layers caused compilation. The Dockerfile changes therefore improve size and cross-version dependency reuse but do not remove the dominant TypeScript/Vite cold-build cost. A prebuilt, digest-pinned release image or native amd64 build worker would be required for a major installation-time reduction.

Instatic's development browser console emitted transient MCP workspace-bridge reconnect messages and a media-variant warning for the tiny test fixture; the asserted workflows still passed.

## Remaining Cloudron release gates

- The first guarded Cloudron install attempt was rejected before provisioning because `packageUrl` is not an allowed Cloudron manifest property. It was removed and a regression assertion was added before retrying.
- Actual PostgreSQL/sendmail credential rotation remains blocked: supported repair and restore workflows did not change either credential.
- Cloudron lifecycle/task logs are not secret-free on the tested platform version. The package cannot redact logs generated outside its container. The owner accepted this platform-wide issue as a known exception for continued Instatic evaluation; it is not currently treated as an Instatic package release blocker.

These remaining items are release gates in `docs/VERIFICATION.md`, not assumed successes.
