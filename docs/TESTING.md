# Testing

Release-specific infrastructure identifiers, accounts, form submissions, task IDs, and raw logs do not belong in this repository. Record only a sanitized result summary in the corresponding GitHub release notes.

## Automated package checks

Extract the pinned upstream Instatic release, then run:

```sh
./test/package-test.sh /path/to/Instatic-0.0.17
bash -n start.sh healthcheck.sh test/cloudron-smoke.sh scripts/*.sh
git diff --check
```

This validates package metadata, immutable image and upstream pins, patch applicability, script structure, persistence paths, health and mail configuration, and common committed-secret patterns.

Build the production image from a clean cache:

```sh
docker build --pull --no-cache -t instatic-cloudron:test .
```

Confirm that the final image uses the expected `linux/amd64` architecture and starts within the manifest's memory limit.

## Disposable Cloudron acceptance

Run the lightweight public checks after installation:

```sh
./test/cloudron-smoke.sh https://app.example.com
```

Then complete the stateful matrix on a disposable instance:

| Area | Required evidence |
|---|---|
| First run | `/admin` offers setup; an owner can be created; no default credential exists |
| PostgreSQL | migrations complete and Instatic tables exist in the Cloudron-managed database |
| Authentication | anonymous admin API access is denied; login works; logout invalidates the session |
| Uploads | uploaded media renders and persists under `/app/data/uploads` |
| Publishing | a published page renders anonymously and remains available after restart |
| Forms | a valid public form submission persists exactly one database row |
| Mail | the configured recipient receives the corresponding notification through Cloudron sendmail |
| Restart | account, content, media, published output, and the persisted secret survive |
| Backup and restore | database content, media, published output, and the secret return from a verified backup |
| Package update | data persists, migrations complete once, and form persistence and delivery still work |
| Domain change | the new origin is accepted and the old origin is rejected after the move |
| Memory | normal authoring, publishing, forms, restart, and backup complete without an OOM restart |
| Logs | app-runtime logs contain no database URL, SMTP password, secret key, token, or submitted form content |

Cloudron platform lifecycle logs are outside the package's control. Treat exported lifecycle logs as sensitive and assess platform-generated entries separately from app stdout/stderr.

## Release gate

Do not tag a stable release or publish `CloudronVersions.json` until the candidate image passes clean-install and populated-upgrade acceptance at the manifest's default memory limit. Generate the catalog with the Cloudron CLI and require `cloudron versions verify` to pass before distribution.
