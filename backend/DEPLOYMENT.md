# Namello Backend Deployment

## Default local mode

No domain, VPS, or Google Client ID is required for development. Use `localhost:8787`.

## Production defaults to secure mode

Production refuses to start in local/demo mode. For Google OAuth mode, configure `GOOGLE_CLIENT_ID`; for Firebase Authentication mode, configure `FIREBASE_PROJECT_ID` and server credentials. Set exact PWA origins in `CORS_ORIGINS`.

Required production values:
- `NAMELLO_AUTH_MODE=firebase` (for Firebase email/password and Google sign-in)
- `FIREBASE_PROJECT_ID=namello-app-4`
- `FIREBASE_SERVICE_ACCOUNT_JSON=<service-account JSON stored as a Render secret>` (or use Application Default Credentials)
- `NAMELLO_SESSION_SECRET=<long random secret>`
- For legacy Google-only mode, use `NAMELLO_AUTH_MODE=google` and `GOOGLE_CLIENT_ID=<real Google Web Client ID>`
- `CORS_ORIGINS=https://<your-pwa-domain>`
- `NAMELLO_API_DOMAIN=<your-api-domain>`

The server stores only account metadata and encrypted sync envelopes; it does not decrypt trade data.
