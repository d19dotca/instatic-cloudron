# Instatic for Cloudron

Production-oriented Cloudron Community App packaging for [Instatic](https://github.com/CoreBunch/Instatic), pinned to upstream `0.0.16`.

## What this package provides

- Cloudron-managed PostgreSQL.
- Persistent uploads, fonts, plugins, and published artifacts under `/app/data/uploads`.
- A generated 256-bit `INSTATIC_SECRET_KEY` persisted in `/app/data/secrets`.
- Cloudron sendmail integration for public form notifications.
- Automatic public-origin configuration after install, restart, restore, or domain change.
- `/health` monitoring, stdout/stderr logging, Cloudron backups, and update-safe immutable code.
- Reproducible upstream and base-image pins, licensing notices, package tests, and Community App metadata.

See [architecture decisions](docs/ARCHITECTURE.md), [verified official references](docs/REFERENCES.md), [local test results](docs/TEST-RESULTS.md), [verification matrix](docs/VERIFICATION.md), and [upstream update procedure](docs/UPSTREAM.md).

## Build and install on a disposable Cloudron

Cloudron's current packaging documentation recommends on-server builds when local Docker is unavailable:

```sh
cloudron login my.example.com
cloudron install --location instatic.example.com
```

From this directory, the CLI uploads the build context, builds the image on the Cloudron, provisions PostgreSQL/localstorage/sendmail, and installs the app. Follow Cloudron CLI prompts; do not commit the local Cloudron login file or tokens.

For a registry build:

```sh
cloudron build --set-build-service --tag registry.example.com/instatic-cloudron:0.1.0
cloudron install --location instatic.example.com --image registry.example.com/instatic-cloudron:0.1.0
```

Open `https://instatic.example.com/admin` and complete first-run setup. There are no package-supplied credentials.

## Email configuration

The sendmail addon is mandatory. Form submissions are saved before mail is attempted. By default, notifications go to the Cloudron-provisioned sender address. To choose another recipient, create `/app/data/env` in the app terminal:

```sh
INSTATIC_FORM_EMAIL_TO='owner@example.com'
INSTATIC_FORM_EMAIL_SUBJECT_PREFIX='[Website]'
```

Restart the app after changing the file. The file is backed up with `/app/data`. Never place Cloudron database or SMTP credentials there; Cloudron injects them at runtime.

To send a transport-only test from the app terminal without exposing the password:

```sh
printf 'To: owner@example.com\nSubject: Instatic Cloudron mail test\n\nMail transport works.\n' | /usr/sbin/sendmail -t
```

## Backups, restore, restart, and domains

Use normal Cloudron app backups. PostgreSQL and `/app/data` are captured together by Cloudron. On restore or restart, the startup script repairs ownership, reloads current addon credentials, reuses the persisted secret, and runs upstream migrations.

Changing the primary app domain is supported automatically because `PUBLIC_ORIGIN` is recomputed from `CLOUDRON_APP_ORIGIN`. If you configure an additional domain alias outside this manifest, list every accepted origin in `/app/data/env`.

## Updates

Read `docs/UPSTREAM.md`. Always test on a disposable clone/restore first, take a fresh backup, and bump the Cloudron package version. Do not change from PostgreSQL to SQLite as an ordinary package update.

## Community App publishing

`CloudronVersions.json` is intentionally not included as a live catalog because no registry image has been published. After the user approves publication:

1. Confirm the final GitHub URLs and packager metadata in `CloudronManifest.json`.
2. Build and push the exact image tag.
3. With current Cloudron CLI tooling installed, run `./scripts/create-community-catalog.sh <docker-image>`.
4. Verify with `cloudron versions verify`.
5. Commit and host `CloudronVersions.json`; users paste its raw HTTPS URL into Cloudron's Community Apps dialog.

Nothing in this repository publishes, pushes, or submits automatically.

## Licenses

The package is MIT-licensed. Instatic is MIT-licensed; its notice is preserved in `LICENSES/Instatic-MIT.txt`. Container base images and installed system packages retain their respective licenses.
