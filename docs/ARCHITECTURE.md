# Architecture and decisions

## Upstream pin

The package builds Instatic `0.0.16` from the official GitHub release archive. The Docker build verifies SHA-256 `c8806c1f487c81b34090e25d9bb17f6bff2b2c02c4025d90fb3e7edbfb15e430` before extracting it. Bun is pinned to `1.3.11` and both build and runtime base images are pinned by digest.

## Database

Cloudron-managed PostgreSQL is the production default. Instatic officially supports PostgreSQL through `DATABASE_URL`, maintains dialect-paired migrations, and runs migrations at startup. Cloudron injects a fresh `CLOUDRON_POSTGRESQL_URL` on every restart; `start.sh` passes it through without storing it.

Why PostgreSQL here, despite upstream preferring SQLite for simple sites:

- Cloudron already owns PostgreSQL provisioning, credentials, backups, restore, and service health.
- A database snapshot is consistent without adding SQLite-specific backup coordination.
- It avoids an active WAL database inside the filesystem backup.
- It preserves the supported path for concurrent authors.

Fallback: Instatic remains SQLite-capable. A SQLite Cloudron variant would set `DATABASE_URL=sqlite:/app/data/database/cms.db` and declare that exact file under the localstorage addon's `sqlite.paths`. It is not the shipping manifest because changing database engines is a migration, not a runtime toggle.

## Persistence and backup

`/app/code` is immutable. Instatic media, fonts, installed plugins, module packs, and published static artifacts live under `/app/data/uploads`. The generated encryption key lives at `/app/data/secrets/instatic-secret-key`. Cloudron backs up `/app/data`; the PostgreSQL addon is backed up as part of the app backup.

Restore requires no special package command: Cloudron restores PostgreSQL and `/app/data`, then `start.sh` repairs ownership and Instatic runs idempotent migrations.

## Public and administration surfaces

Instatic serves published static HTML/CSS itself. The package does not introduce a frontend proxy or framework runtime, so fully static pages retain upstream's baked-page behavior.

`/admin` uses Instatic's native accounts, session cookies scoped to `/admin`, CSRF origin validation, login rate limits, step-up authentication, role capabilities, and optional TOTP MFA. Cloudron `proxyAuth` is intentionally not enabled because it would add a second login without provisioning or role-mapping Instatic users.

`PUBLIC_ORIGIN` is recomputed from `CLOUDRON_APP_ORIGIN` at every start, which supports primary-domain changes. Additional aliases require an explicit comma-separated override in `/app/data/env`.

## Mail patch

Upstream 0.0.16 persists CMS-native form submissions but has no SMTP transport and emits no plugin hook from the public form handler. Instatic plugins run in QuickJS and cannot open SMTP sockets, so a plugin-only integration is not possible.

`patches/0001-cloudron-form-email.patch` adds one mail module and one guarded call after the database row is created. It invokes the standard `sendmail` interface, which `msmtp` routes through Cloudron's sendmail addon. Delivery failure is logged and does not roll back the already-persisted submission. The patch is transport-generic and suitable for proposing upstream as an optional sendmail notification hook.

The default recipient is `CLOUDRON_MAIL_FROM`; operators can override it with `INSTATIC_FORM_EMAIL_TO` in `/app/data/env`.
