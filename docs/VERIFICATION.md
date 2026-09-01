# Verification matrix

## Automated locally

Run:

```sh
./test/package-test.sh /path/to/Instatic-0.0.17
```

This validates metadata, pinned images/releases, patch applicability, scripts, persistence paths, health configuration, mail configuration, and common secret patterns.

If Docker is available:

```sh
docker build --pull --no-cache -t instatic-cloudron:0.1.4 .
```

## Disposable Cloudron acceptance test

The package is not production-ready until these are checked on a disposable install:

| Area | Expected evidence |
|---|---|
| First run | `/admin` offers setup; owner can be created; no default credential exists |
| PostgreSQL | startup logs show migrations and the PostgreSQL service has Instatic tables |
| Admin | anonymous admin API is denied after setup; owner login works; logout invalidates session |
| Uploads | uploaded image renders from `/uploads`; file exists under `/app/data/uploads` |
| Publish | published page renders anonymously and remains available after restart |
| Static performance | fully static page has baked HTML and does not load a frontend framework runtime |
| Form | valid public CMS form persists exactly one submission row |
| Email | the configured recipient receives one real message through Cloudron sendmail |
| Restart | owner, content, upload, published page, and secret-key checksum persist |
| Domain change | admin POST succeeds on the new origin and fails for the old origin |
| Backup/restore | a pre-change backup restores DB content, uploads, published output, and secret |
| Update | package update preserves data and migrations complete once |
| Logs | app logs stream to Cloudron; mail errors contain no SMTP password |

The 2026-09-01 populated-instance matrix is recorded in `docs/ACCEPTANCE-0.1.3.md`. Restore, repeat update, both domain moves, and post-operation forms passed. Actual addon credential rotation remains blocked because Cloudron preserved both credentials across repair and same-backup restore. The package's app-runtime logs were secret-free, but Cloudron lifecycle logs disclosed injected addon credentials; therefore a blanket "all Cloudron logs contain no secrets" gate is not met by this platform version.

Run the lightweight remote checks after installation:

```sh
./test/cloudron-smoke.sh https://app.example.com
```

The script deliberately does not create accounts or content. Complete mutation tests interactively against a disposable instance so credentials are never stored in this repository.
