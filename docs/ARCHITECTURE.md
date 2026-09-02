# Architecture and decisions

## Upstream pin

The package builds Instatic `0.0.17` from the official GitHub release archive. The Docker build verifies SHA-256 `53a9ca19f798db7459d81ca96c15d1fe9000a970bde6f544adf660b292ee5bae` before extracting it. Bun is pinned to `1.3.11` and both build and runtime base images are pinned by digest.

## Database

Cloudron-managed PostgreSQL is the production default. Instatic officially supports PostgreSQL through `DATABASE_URL`, maintains dialect-paired migrations, and runs migrations at startup. Cloudron injects the current `CLOUDRON_POSTGRESQL_URL` on every restart; `start.sh` passes it through without storing it.

Cloudron-managed addon environment values are dynamic and may change across restart, restore, or reprovisioning. The package therefore does not define a manual credential-rotation procedure or cache database credentials. Moving or restoring content into a newly provisioned app is the acceptance path when a distinct credential set must be demonstrated.

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

`PUBLIC_ORIGIN` is recomputed from `CLOUDRON_APP_ORIGIN` and `CLOUDRON_ALIAS_DOMAINS` at every start. Instatic accepts multiple public origins and serves published routes independently of the request hostname, so Cloudron location aliases can serve the same site without redirecting. `TRUSTED_PROXY_CIDRS` is set to Cloudron's exact `CLOUDRON_PROXY_IP`, allowing Instatic to use Cloudron's forwarded client address for audit logs and per-IP rate limits without trusting arbitrary peers.

## Forms and mail boundary

Upstream Instatic `0.0.17` validates CMS-native form submissions and persists them to data tables, but does not provide form-submission email notifications. The Community App deliberately does not patch Instatic or request Cloudron's sendmail addon. This keeps application behavior owned by upstream and avoids carrying a source patch across upgrades.

Email notification should be added through a supported, platform-neutral upstream capability. Until then, installations requiring notification delivery need a separately maintained experimental image; the Community App's form data table remains the authoritative submission record.
