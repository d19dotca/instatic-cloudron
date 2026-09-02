# Contributing

Thanks for helping improve Instatic's Cloudron packaging. This repository owns the Cloudron integration around upstream Instatic; it does not maintain Instatic itself.

## Where an issue belongs

- Report manifest, container startup, persistence, backup, restore, Cloudron proxy, or Community App catalog problems here.
- Report Instatic editor, publishing, form, plugin, or application behavior to the [upstream Instatic project](https://github.com/CoreBunch/Instatic/issues) unless the problem occurs only in this package.
- Report package security issues privately through [GitHub Security Advisories](https://github.com/d19dotca/instatic-cloudron/security/advisories/new), not a public issue.

## Pull requests

Keep changes narrowly scoped and do not include credentials, raw Cloudron lifecycle logs, database exports, form submissions, backups, or persisted secret contents.

Before opening a pull request:

1. Read `docs/ARCHITECTURE.md` and `docs/UPSTREAM.md`.
2. Run `./test/package-test.sh /path/to/Instatic-0.0.17`.
3. Run `bash -n start.sh healthcheck.sh test/*.sh scripts/*.sh` and `git diff --check`.
4. Build the complete `linux/amd64` image from a clean cache.
5. Describe any Cloudron acceptance performed and clearly identify checks that remain untested.

## Release policy

Published `CloudronVersions.json` entries and registry tags are treated as immutable. Every behavior or image change receives a new package version. A release requires a clean installation and a populated update test at the manifest's default memory limit before it is promoted from candidate testing to the published catalog.

Maintaining or contributing to this community package is best-effort. Opening a pull request does not create an obligation to provide ongoing support.
