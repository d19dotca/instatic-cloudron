# Instatic for Cloudron

[![Package checks](https://github.com/d19dotca/instatic-cloudron/actions/workflows/package.yml/badge.svg)](https://github.com/d19dotca/instatic-cloudron/actions/workflows/package.yml)
[![Latest release](https://img.shields.io/github/v/release/d19dotca/instatic-cloudron?label=package)](https://github.com/d19dotca/instatic-cloudron/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Cloudron Community App packaging for [Instatic](https://github.com/CoreBunch/Instatic), pinned to upstream `0.0.18`.

> **Release status:** package `0.1.4` is the latest published catalog release. Package `0.2.0` is an unreleased candidate under validation. The `main` branch can therefore be newer than the catalog; use `CloudronVersions.json` unless you intentionally want to test package development.

## Install as a Community App

Add this catalog URL under **Cloudron Dashboard → Settings → Community Apps**:

```text
https://raw.githubusercontent.com/d19dotca/instatic-cloudron/main/CloudronVersions.json
```

The catalog installs the published `linux/amd64` image from GitHub Container Registry. Cloudron 10.0.0 or newer is required.

## What this package provides

- Cloudron-managed PostgreSQL.
- Persistent uploads, fonts, plugins, and published artifacts under `/app/data/uploads`.
- A unique random 256-bit `INSTATIC_SECRET_KEY` generated on first start and persisted in `/app/data/secrets` for that installation.
- Automatic public-origin and trusted-proxy configuration after install, restart, restore, primary-domain change, or alias change.
- Cloudron health monitoring through Instatic's `/health` endpoint, stdout/stderr logging, Cloudron backups, and update-safe immutable code.
- Reproducible upstream and base-image pins, licensing notices, package tests, and Community App metadata.

See [architecture decisions](docs/ARCHITECTURE.md), [testing procedure](docs/TESTING.md), and [upstream update procedure](docs/UPSTREAM.md).

## Build and install on a disposable Cloudron

Cloudron's current packaging documentation recommends on-server builds when local Docker is unavailable:

```sh
cloudron login my.example.com
cloudron install --location instatic.example.com
```

From this directory, the CLI uploads the build context, builds the image on the Cloudron, provisions PostgreSQL and local storage, and installs the app. Follow Cloudron CLI prompts; do not commit the local Cloudron login file or tokens.

To update an existing development installation from the checked-out package, keep Cloudron's automatic safety backup enabled:

```sh
cloudron update --app instatic.example.com
```

For a registry build, replace the example repository with one you control. Cloudron CLI 9 uses the `builder build` subcommand:

```sh
version=$(jq -r .version CloudronManifest.json)
cloudron builder build --repository "username/instatic-cloudron" --tag "${version}"
cloudron install --location instatic.example.com --image "registry.example.com/instatic-cloudron:${version}"
```

Open `https://instatic.example.com/admin` and complete first-run setup. There are no package-supplied credentials.

## Memory sizing

The package defaults to 512 MiB, which is the supported minimum for a typical installation. Increase the limit for high-traffic production sites or workloads involving heavier plugins, image processing, frequent publishing, or concurrent editors. Monitor the app's memory usage in Cloudron and size it for the site's actual workload; 1 GiB or more may be appropriate for busier installations.

## Health monitoring

Cloudron queries Instatic's `/health` endpoint and considers the app healthy when it returns an HTTP 2xx status. Instatic currently returns a JSON body containing `"status":"ok"`, but Cloudron evaluates the HTTP status rather than matching response text. A non-2xx response or an unreachable endpoint causes Cloudron to report the app as not responding. The image's Docker health check uses the same 2xx-status rule.

## Forms and email notifications

The Community App ships Instatic's native form behavior without downstream application patches. CMS-native forms validate submissions and save them to their configured Instatic data tables. Upstream Instatic `0.0.18` does not send form-submission email notifications, and this package does not request Cloudron's sendmail addon.

If email notification is required, use a separately maintained experimental image or a supported upstream integration when one becomes available. Keep the Instatic data table as the authoritative submission record.

## Backups, restore, restart, and domains

Use normal Cloudron app backups. PostgreSQL and `/app/data` are captured together by Cloudron. On restore or restart, the startup script repairs ownership, reloads current addon credentials, reuses the persisted secret, and runs upstream migrations.

Changing the primary app domain or adding a Cloudron location alias is supported automatically. The package rebuilds Instatic's accepted `PUBLIC_ORIGIN` list from `CLOUDRON_APP_ORIGIN` and `CLOUDRON_ALIAS_DOMAINS` on every start. Each alias serves the same Instatic site; use a Cloudron redirection instead when an alternate domain should always redirect to the primary domain.

## Updates

Read `docs/UPSTREAM.md`. Always test on a disposable clone/restore first, take a fresh backup, and bump the Cloudron package version. Do not change from PostgreSQL to SQLite as an ordinary package update.

Published catalog versions are immutable. Candidate changes are released under a new package version, built as `linux/amd64`, tested on Cloudron, pushed to GHCR, and only then added to `CloudronVersions.json`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution and release expectations.

## Support

Use [GitHub Issues](https://github.com/d19dotca/instatic-cloudron/issues) for reproducible package problems and installation questions. Include the package version, Cloudron version, and sanitized logs. Do not post credentials, database exports, form submissions, or raw lifecycle logs containing addon configuration.

Package-specific security reports should be submitted privately through [GitHub Security Advisories](https://github.com/d19dotca/instatic-cloudron/security/advisories/new). Upstream Instatic defects belong in the [Instatic issue tracker](https://github.com/CoreBunch/Instatic/issues).

Only the latest package release is supported on a best-effort community basis. This repository maintains the Cloudron integration; application defects and feature requests belong in the upstream [Instatic issue tracker](https://github.com/CoreBunch/Instatic/issues).

## Licenses

The package is MIT-licensed. Instatic is MIT-licensed; its notice is preserved in `LICENSES/Instatic-MIT.txt`. Container base images and installed system packages retain their respective licenses.
