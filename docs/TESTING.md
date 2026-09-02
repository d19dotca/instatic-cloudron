# Testing

Release-specific infrastructure identifiers, accounts, form submissions, task IDs, and raw logs do not belong in this repository. Record only a sanitized result summary in the corresponding GitHub release notes.

## Automated package checks

Extract the pinned upstream Instatic release, then run:

```sh
./test/package-test.sh /path/to/Instatic-0.0.17
bash -n start.sh healthcheck.sh test/cloudron-smoke.sh scripts/*.sh
git diff --check
```

This validates package metadata, immutable image and upstream pins, script structure, persistence paths, health configuration, the absence of downstream source patches, and common committed-secret patterns.

Build the production image from a clean cache:

```sh
docker build --pull --no-cache -t instatic-cloudron:test .
```

Confirm that the final image uses the expected `linux/amd64` architecture and starts within the manifest's memory limit.

## Disposable Cloudron acceptance

A catalog installation displays the manifest `title` and `upstreamVersion` as the dashboard's **App title & version** (for this package, `Instatic 0.0.17`). A source-upload development install has no Community App catalog identity, so Cloudron can instead display its generated `local/...` Docker image name. Do not treat that development-only fallback as missing manifest metadata.

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
| Health | `/health` returns HTTP 2xx and Cloudron reports the app healthy; a disposable failure build returning non-2xx is reported as not responding |
| Forms | a valid public form submission persists exactly one database row |
| Restart | account, content, media, published output, and the persisted secret survive |
| Backup and restore | database content, media, published output, and the secret return from a verified backup |
| Package update | a populated `0.1.4` instance updates to `0.2.0`; data persists; migrations complete once; removing sendmail does not affect startup; any legacy `/app/data/env` file remains inert; form rows still persist and no notification is attempted |
| Domain change | the new origin is accepted and the old origin is rejected after the move |
| Domain alias | a Cloudron location alias serves the same published site; authenticated mutations accept the alias origin; removing the alias removes that accepted origin after restart |
| Client IP | audit activity and per-IP rate-limit keys use the forwarded client address only when the socket peer is `CLOUDRON_PROXY_IP` |
| Memory | normal authoring, publishing, forms, restart, and backup complete without an OOM restart |
| Logs | app-runtime logs contain no database URL, addon credential, secret key, token, or submitted form content |

Cloudron platform lifecycle logs are outside the package's control. Treat exported lifecycle logs as sensitive and assess platform-generated entries separately from app stdout/stderr.

## Addon credential lifecycle

Cloudron does not expose manual PostgreSQL credential rotation as an ordinary app operation. Addon environment variables can change after restart, restore, or addon reprovisioning, so `start.sh` reads `CLOUDRON_POSTGRESQL_URL` on every start and never persists it. Do not treat a repair that retains the same credential as a failed package test. When new credentials must be proved, restore or migrate the content into a newly provisioned disposable instance and verify healthy startup there.

## Release gate

Do not tag a stable release or publish `CloudronVersions.json` until the candidate image passes clean-install and populated-upgrade acceptance at the manifest's default memory limit. Generate the catalog with the Cloudron CLI and require `cloudron versions verify` to pass before distribution.
