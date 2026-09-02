# Upstream review and update procedure

## Reviewed upstream contract

- Repository and license: `CoreBunch/Instatic`, MIT.
- Release packaged: `v0.0.17`, published 2026-08-30.
- Runtime: one Bun server for public pages, admin SPA/API, uploads, forms, and publishing.
- Database: SQLite or PostgreSQL selected by `DATABASE_URL`; migrations run on boot.
- Persistent upload root: `UPLOADS_DIR`, including media and `published/current`.
- Public origin: `PUBLIC_ORIGIN`, required behind a TLS-terminating proxy for CSRF validation.
- Health route: `/health`.

## Update checklist

1. Read the upstream release notes and deployment, database-dialect, backup, forms, authentication, and licensing documentation.
2. Set the new `INSTATIC_VERSION` and official archive SHA-256 in `Dockerfile`.
3. Update `upstreamVersion`, package `version`, and `CHANGELOG`.
4. Run `./scripts/verify-upstream.sh /path/to/extracted/source`.
5. Confirm the package still builds unmodified upstream source. If upstream gains a supported mail capability, evaluate it separately instead of introducing a downstream source patch.
6. Run `./test/package-test.sh` and `docker build --pull --no-cache .`.
7. Install on a disposable Cloudron and run `./test/cloudron-smoke.sh https://app.example.com` plus the manual matrix in `docs/TESTING.md`.
8. Take a Cloudron backup, update the disposable app, verify persisted content/uploads/published output, then restore the backup and verify again.
9. Only after review, build and push the image, update `CloudronVersions.json`, and publish the Git commit/tag.

Do not use `latest` tags or silently change database engines during an update.
