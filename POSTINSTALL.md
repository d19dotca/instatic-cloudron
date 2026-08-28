Instatic is ready at **$CLOUDRON-APP-ORIGIN**.

1. Open **$CLOUDRON-APP-ORIGIN/admin**.
2. Complete Instatic's first-run setup and create the owner account. No default credentials are generated.
3. Publish a page and verify it anonymously.
4. Form notifications default to the Cloudron sender address. To send them elsewhere, create `/app/data/env` with `INSTATIC_FORM_EMAIL_TO='recipient@example.com'`, then restart the app.

The admin area uses Instatic's own accounts, sessions, CSRF protection, login rate limiting, step-up authentication, and optional TOTP MFA. Cloudron dashboard visibility does not grant an Instatic account.
