# Namello Backend Deployment

## Production with Firebase Authentication

Use Node.js 22.5 or newer. Configure the following variables in your hosting provider's environment/secret settings:

- `NODE_ENV=production`
- `NAMELLO_AUTH_MODE=firebase`
- `FIREBASE_PROJECT_ID=namello-app-4`
- `NAMELLO_SESSION_SECRET=<cryptographically-random-secret-at-least-32-characters>`
- `CORS_ORIGINS=https://<your-exact-app-domain>`
- `NAMELLO_API_DOMAIN=<your-api-domain>` (if used by your Caddy setup)

The backend verifies Firebase ID tokens using Firebase Admin SDK Application Default Credentials. On Google Cloud, prefer a dedicated service identity with least privilege. Outside Google Cloud, use the host's secret manager to configure ADC securely. Never commit or share service-account private keys.

The frontend must POST the current Firebase ID token to `/v1/auth/firebase/verify`; only after the backend returns its own session token should the client call account/sync endpoints. Email/password accounts must verify their email first. Google sign-in must return a verified email.

## Existing Google-only mode

For installations that still use direct Google OAuth tokens, set `NAMELLO_AUTH_MODE=google` and `GOOGLE_CLIENT_ID=<real Google Web Client ID>`.

## Local development

Local auth is only for development and must not be exposed in production. Production startup refuses `NAMELLO_AUTH_MODE=local`.

The server stores account metadata and encrypted sync envelopes; it does not decrypt trade data. Always use HTTPS and restrict `CORS_ORIGINS` to the exact deployed app origin(s).
