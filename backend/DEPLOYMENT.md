# Namello Backend Deployment

## Production mode: Google OAuth

This source bundle uses Google ID-token verification for backend sessions. It does **not** use Firebase Web Authentication, so the Firebase Web `apiKey` error from a different `index.html` does not originate from this source.

Set these environment variables on Render:

- `NODE_ENV=production`
- `NAMELLO_AUTH_MODE=google`
- `GOOGLE_CLIENT_ID=<the same Google OAuth Web Client ID used in Namello settings>`
- `NAMELLO_SESSION_SECRET=<at least 32 random characters>`
- `CORS_ORIGINS=https://nrazaniemail-ship-it.github.io`
- `DB_PATH=/var/data/namello.sqlite` (only if a persistent disk is mounted at `/var/data`; otherwise choose a persistent storage plan/path appropriate to the Render service)

The Google OAuth Web Client ID must be configured for the app's actual origin and redirect/popup use in Google Cloud Console. The client ID is not a client secret. Never put a Google client secret or service-account private key in the browser.

## Local development

Use Node.js 22.5 or later. The local mode is intended only for development:

- `NODE_ENV=development`
- `NAMELLO_AUTH_MODE=local`
- `NAMELLO_SESSION_SECRET=<at least 32 random characters>`

Do not enable local/demo auth in production. The service uses Node's built-in SQLite support, so ensure the deployed runtime supports `node:sqlite` and attach persistent storage if sync records must survive redeploys.

## Health check

`GET /healthz` returns the backend status and active authentication mode. A successful health check does not itself prove Google sign-in works; test the full sign-in flow from the deployed PWA.
