# Instatic for Cloudron

Cloudron Community App packaging for [Instatic](https://github.com/CoreBunch/Instatic), pinned to upstream `0.0.17`.

Package `0.1.4` is the first public release. The current `main` branch may contain an unreleased candidate; install through `CloudronVersions.json` unless you are testing package development.

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
- Automatic public-origin configuration after install, restart, restore, or domain change.
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

For a registry build, replace the example version with the candidate in `CloudronManifest.json`:

```sh
version=$(jq -r .version CloudronManifest.json)
cloudron build --set-build-service --tag "registry.example.com/instatic-cloudron:${version}"
cloudron install --location instatic.example.com --image "registry.example.com/instatic-cloudron:${version}"
```

Open `https://instatic.example.com/admin` and complete first-run setup. There are no package-supplied credentials.

## Memory sizing

The package defaults to 512 MiB, which is the supported minimum for a typical installation. Increase the limit for high-traffic production sites or workloads involving heavier plugins, image processing, frequent publishing, or concurrent editors. Monitor the app's memory usage in Cloudron and size it for the site's actual workload; 1 GiB or more may be appropriate for busier installations.

## Health monitoring

Cloudron queries Instatic's `/health` endpoint and considers the app healthy when it returns an HTTP 2xx status. Instatic currently returns a JSON body containing `"status":"ok"`, but Cloudron evaluates the HTTP status rather than matching response text. A non-2xx response or an unreachable endpoint causes Cloudron to report the app as not responding. The image's Docker health check uses the same 2xx-status rule.

## Forms and email notifications

The Community App ships Instatic's native form behavior without downstream application patches. CMS-native forms validate submissions and save them to their configured Instatic data tables. Upstream Instatic `0.0.17` does not send form-submission email notifications, and this package does not request Cloudron's sendmail addon.

If email notification is required, use a separately maintained experimental image or a supported upstream integration when one becomes available. Keep the Instatic data table as the authoritative submission record.

## Backups, restore, restart, and domains

Use normal Cloudron app backups. PostgreSQL and `/app/data` are captured together by Cloudron. On restore or restart, the startup script repairs ownership, reloads current addon credentials, reuses the persisted secret, and runs upstream migrations.

Changing the primary app domain is supported automatically because `PUBLIC_ORIGIN` is recomputed from `CLOUDRON_APP_ORIGIN`. If you configure an additional domain alias outside this manifest, list every accepted origin in `/app/data/env`.

## Updates

Read `docs/UPSTREAM.md`. Always test on a disposable clone/restore first, take a fresh backup, and bump the Cloudron package version. Do not change from PostgreSQL to SQLite as an ordinary package update.

## Support

Use [GitHub Issues](https://github.com/d19dotca/instatic-cloudron/issues) for reproducible package problems and installation questions. Include the package version, Cloudron version, and sanitized logs. Do not post credentials, database exports, form submissions, or raw lifecycle logs containing addon configuration.

Package-specific security reports should be submitted privately through [GitHub Security Advisories](https://github.com/d19dotca/instatic-cloudron/security/advisories/new). Upstream Instatic defects belong in the [Instatic issue tracker](https://github.com/CoreBunch/Instatic/issues).

Only the latest package release is supported on a best-effort community basis.

## Licenses

The package is MIT-licensed. Instatic is MIT-licensed; its notice is preserved in `LICENSES/Instatic-MIT.txt`. Container base images and installed system packages retain their respective licenses.
