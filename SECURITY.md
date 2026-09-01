# Security policy

Report package-specific vulnerabilities privately to the packager through the security contact mechanism on the package repository. Report upstream Instatic vulnerabilities to the Instatic maintainers.

Do not include live Cloudron tokens, addon credentials, form submissions, database dumps, `/app/data/env`, or `instatic-secret-key` contents in issues or logs.

Cloudron lifecycle/task logs are outside the app container and may include addon environment values during provisioning. The package startup script must never enable shell tracing or dump its environment, but it cannot redact platform-generated `services: Setting ... addon config` entries. Treat any exported lifecycle log containing those entries as sensitive, restrict its distribution, and rotate affected credentials through a Cloudron-supported mechanism when one is available.

Supported package releases are the latest package version only. Before disclosure, identify whether the issue belongs to the Cloudron packaging, the minimal mail patch, Instatic, Bun, or a base-image/system dependency.
