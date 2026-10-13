# Namello Sync Backend

## Local development

Use Node.js 22.5 or newer. Install dependencies and configure a strong local session secret:

```bash
npm install
NAMELLO_SESSION_SECRET='replace-with-a-random-secret-at-least-32-characters' npm start
```

The default local mode is for development only and exposes `POST /v1/auth/dev`. Never enable local mode in production.

## Production with Firebase Authentication

Set these environment variables in the backend hosting service (do not commit secrets):

- `NODE_ENV=production`
- `NAMELLO_AUTH_MODE=firebase`
- `FIREBASE_PROJECT_ID=namello-app-4`
- `NAMELLO_SESSION_SECRET` — a cryptographically random secret of at least 32 characters
- `CORS_ORIGINS` — exact HTTPS origin(s) of the deployed Namello app, comma-separated
- `PORT` if required by the hosting platform

The backend uses Firebase Admin SDK Application Default Credentials. Prefer a hosting platform service identity with only the permissions it needs. If hosting outside Google Cloud, configure Application Default Credentials securely using your host's secret manager; never commit a service-account JSON file or paste its private key into chat.

### Authentication exchange

After a user signs in through Firebase Web Auth, the client sends the Firebase ID token to `POST /v1/auth/firebase/verify` as JSON: `{ "idToken": "..." }`. The server validates the token with Firebase Admin SDK, checks the project and token validity/revocation, permits only Google or email/password providers, and requires a verified email before issuing a Namello sync session. The response contains the Namello session `token`; use that token as `Authorization: Bearer <token>` for the existing `/v1` endpoints.

The client must never treat a Firebase login alone as a Namello backend session. Exchange the ID token server-side and handle `email_verification_required` by asking the user to verify their email and sign in again.

## Other modes

- `NAMELLO_AUTH_MODE=google` preserves the existing direct Google ID-token verification flow and requires `GOOGLE_CLIENT_ID`.
- `NAMELLO_AUTH_MODE=local` is only for development.

## Security and sync

The backend stores account metadata and encrypted sync envelopes; it does not decrypt trade data. Use HTTPS, restrict CORS to exact app origins, and keep all server credentials out of the repository.
