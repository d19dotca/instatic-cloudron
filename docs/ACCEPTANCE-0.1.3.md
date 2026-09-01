# Populated Cloudron acceptance: package 0.1.3

Tested 2026-09-01 against app ID `909993c1-995d-4051-8716-39dc4e207a87`, normally located at `instatic3.d19.ca`. No repository, GitHub, or Cloudron Community publication was performed.

## Final state

- Cloudron readback: installed, running, healthy.
- Package version: `0.1.3`; upstream Instatic version: `0.0.17`.
- Primary location returned to `instatic3.d19.ca`.
- PostgreSQL counts: 5 data tables, 8 data rows, 24 schema migrations, 0 media assets.
- Current app-runtime log: 4,399 bytes, 21 lines, zero credential-pattern findings.

A separate clean-install comparison app is installed at `instatic4.d19.ca` with app ID `dc26075d-5108-4c46-9330-30fe105993e0`. It is running and healthy on package `0.1.3` / Instatic `0.0.17`, remains at the first-run setup screen, and has no administrator users or user-created rows.

## Clean-install and build timing

The clean `instatic4.d19.ca` deployment completed in approximately 17 seconds end to end through the Connector. Cloudron's app creation timestamp to the first healthy readback was approximately 8 seconds. Restart task 36681 completed in 2 seconds by Cloudron timestamps; the internal taskworker reported 0.583 seconds, and the app log showed Instatic listening within the log's one-second timestamp resolution. Public checks returned `/health` in 0.388 seconds and `/admin` in 0.550 seconds.

This fast clean install reused existing Docker build layers. A controlled no-cache `linux/amd64` package build on the Apple-silicon test machine took 186.52 seconds. The dominant step was `bun run build` at 127.0 seconds: TypeScript took approximately 81 seconds before Vite began, then Vite took 45.57 seconds while transforming 2,067 modules. Source-stage package installation took 35.9 seconds, and final image export/unpack took 8.4 seconds. The same build with a warm cache took 2.21 seconds.

The local image reports 3.99 GB, dominated by the Cloudron base image. App-specific layers include approximately 152 MB of production dependencies, 98.5 MB for Bun, 19 MB of source, 13.4 MB of built output, and a 188 MB recursive ownership layer. The ownership layer is a packaging optimization candidate, but disk export is not the main cold-build bottleneck.

Conclusion: the long wait observed on the populated app was principally a source-build/cache issue, not slow Instatic startup. The package compiles a substantial TypeScript/Vite application as part of a local Community App build, and the Cloudron target is pinned to `linux/amd64`; emulation on Apple silicon likely adds cost. Once the image layers exist, fresh deployment and restart are quick.

## Operation matrix

| Operation | Cloudron evidence | Persistence and mail evidence | Result |
|---|---|---|---|
| First 0.1.2 to 0.1.3 update | Task 36663 completed; exact healthy 0.1.3/0.0.17 readback; pre-update backup `..._49aa00d9` | Marker `ACCEPT-0.0.17-UPDATE1-20260901-1805` persisted; Apple Mail confirmed the matching notification | Pass |
| Restore pre-update 0.1.2 backup | Safety backup `..._5a572bf8`; task 36666 completed; exact healthy 0.1.2/0.0.16 readback | The first immediate browser attempt was correctly rejected by the two-second anti-bot minimum. A delayed retry, `ACCEPT-RESTORE-0.1.2-20260901-1830`, persisted as row `lW1vc10lhdqCqPYoVwvtz`; Cloudron recorded queued and locally saved mail events | Pass |
| Repeat in-place update to 0.1.3 | Task 36667 completed; exactly one attributable pre-update backup `..._9c2ae8ed`; exact healthy 0.1.3/0.0.17 readback | `ACCEPT-UPDATE2-0.1.3-20260901-1804` persisted as row `a1_Ec8Yaiok8AfUU4KzUQ`; Cloudron recorded queued and locally saved mail events | Pass |
| Move to `instatic17.d19.ca` | Task 36668 completed; healthy exact-FQDN readback; valid HTTPS on the new origin; old origin no longer served the app with a valid certificate | `ACCEPT-DOMAIN-NEW-0.1.3-20260901-1805` persisted as row `2cDrNDFip_bBFLWqck38B`; Cloudron recorded queued and locally saved mail events under the location-adjusted app sender | Pass |
| Return to `instatic3.d19.ca` | Task 36669 completed; healthy exact-FQDN readback | `ACCEPT-DOMAIN-RETURN-0.1.3-20260901-1806` persisted as row `ChAgHiirGPZ3XBDDabGa4`; Cloudron recorded queued and locally saved mail events | Pass |
| PostgreSQL and mail credential rotation | Repair task 36671 and self-restore task 36674 completed successfully, each after a verified safety backup. Secret-free before/after comparison showed PostgreSQL changed: false; mail changed: false | `ACCEPT-CREDENTIAL-ATTEMPT-0.1.3-20260901-1810` persisted as row `pQAMPuvFsiyVL5_OPIMat`; its Cloudron message was queued and saved to the local mailbox | Blocked by Cloudron capability; app remained healthy |

## Credential disclosure finding

The supplied 105,190-byte lifecycle log contains real PostgreSQL addon values at lines 30 and 754 and real sendmail addon values at lines 33 and 755. Four other matches at lines 627-630 are benign test names mentioning `DATABASE_URL`.

The disclosure is generated by Cloudron's lifecycle logger: each sensitive entry begins with `services: Setting postgresql addon config to` or `services: Setting sendmail addon config to`. It occurs during platform provisioning/update, before the package startup output. The package `start.sh` uses `set -euo pipefail`, never enables `set -x`, never dumps the environment, and writes the SMTP password only to a root-owned runtime file under `/run/instatic`.

Conclusion: this specific disclosure is not caused by the Instatic package and cannot be fixed inside it. Removing the standard `postgresql` or `sendmail` manifest addons would break required functionality without preventing the platform logger from mishandling other apps' addon values. Cloudron documents that addon values are platform-injected and may change across restarts, restores, and reprovisioning: <https://docs.cloudron.io/packaging/addons/>.

This remains a Cloudron platform security/privacy defect and fails any blanket requirement that all Cloudron lifecycle logs be secret-free. Exported copies must be treated as sensitive. The current app-runtime log itself passed the secret scan. Raw per-task logs for tasks 36663, 36666-36669, 36671, and 36674 were already unavailable from Cloudron (`HTTP 424 Log file removed/missing`), so the supplied combined lifecycle log is the retained evidence.

On 2026-09-01, the owner accepted this platform-wide Cloudron logging concern as a known exception for the purpose of continuing Instatic package evaluation. It is not treated as an Instatic package defect or a current package release blocker. This acceptance does not make exported lifecycle logs non-sensitive and does not waive the unresolved credential-rotation test.

## Connector notes

The local Cloudron Connector was advanced through 0.9.6 while completing this matrix. Fixes include bounded transient API retries, quiet PostgreSQL CSV framing, correct verified-result precedence, restore-based credential-rotation proof, strict verified-backup ID binding, and repaired app-log artifact authorization. Its full 17-stage local test command passed after the final update.

The credential-rotation tool deliberately fails closed when Cloudron preserves credentials. A destructive reinstall/migration or unsupported direct service manipulation was not attempted. A private Cloudron security/support report and any publication require owner approval.
