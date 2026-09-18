# Instatic for Cloudron

Cloudron packaging for [Instatic](https://instatic.com), an open-source visual CMS that publishes plain HTML and CSS.

This package uses Instatic's official Linux release artifact and adds only the Cloudron integration needed for PostgreSQL, persistent uploads, backups, health checks, proxy-aware origins, and a per-install encryption key.

## Install

This is a community package under active testing. Add the published catalog URL to **Cloudron Dashboard → Settings → Community Apps** once a release is listed in `CloudronVersions.json`:

```text
https://raw.githubusercontent.com/d19dotca/instatic-cloudron/main/CloudronVersions.json
```

Cloudron 10 or newer is required. After installation, open `/admin` and create the owner account. Instatic manages its own users; Cloudron users are not signed in automatically.

## Package notes

- PostgreSQL data and `/app/data` are included in Cloudron backups.
- Uploaded media, fonts, plugins, and published files persist under `/app/data/uploads`.
- The package derives trusted origins from the Cloudron primary domain and aliases on every start.
- Instatic `0.0.20` stores native form submissions but does not send submission emails.
- Package issues belong in this repository. Application issues belong in the [Instatic repository](https://github.com/CoreBunch/Instatic/issues).

## Testing an update

Run `./test/package-test.sh`, build the image for `linux/amd64`, then verify a clean install and a populated upgrade on a disposable Cloudron. Confirm first-run setup, PostgreSQL migrations, uploads, publishing, forms, restart, backup/restore, health, and domain aliases before publishing a package release.

Published catalog entries and image tags are immutable. Create a new package version for every update.

## Upstream updates

The daily `upstream-update` workflow checks GitHub's latest stable Instatic release. When a newer version is available, it verifies the official Linux x64 artifact checksum, increments the Cloudron package patch version, updates the package sources, runs the package tests, builds a disposable `linux/amd64` image, and creates or refreshes one review pull request.

The updater never publishes an image, GitHub release, catalog entry, or Cloudron update. Before release, a maintainer must review the changes and validate a clean install plus a populated upgrade on a disposable Cloudron.
