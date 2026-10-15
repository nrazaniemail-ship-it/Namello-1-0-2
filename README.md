# Namello 1.0.5

Namello is a Persian-first trading journal PWA with local storage, backup/restore, custom journal fields, trade statistics, psychology and market-behavior evaluation, notification settings, MT5/TradingView helpers, and an optional Google OAuth-backed encrypted sync service.

## This release

- Version: `1.0.5`
- Android `versionCode`: `72`
- Fixed backend startup order so `NODE_ENV` is defined before it is used to select the authentication mode.
- Kept the existing app architecture and its feature/test coverage instead of rewriting the 2 MB single-file UI without a migration plan.
- Synchronized the web build output and service-worker cache with the release version.

## Build and verify

Use Node.js 22.5 or later.

```sh
npm test
npm run typecheck
npm run verify
npm run build
node --check backend/server.mjs
```

## Deployment notes

- GitHub Pages serves the root `index.html`; upload the **contents** of this folder to the repository root, not the enclosing folder.
- The source in this bundle uses Google OAuth for the optional backend sync. It does not include the Firebase Web login gate that was present in a different deployed `index.html`.
- Before deploying the backend to Render, follow [`backend/DEPLOYMENT.md`](backend/DEPLOYMENT.md) and configure `NAMELLO_AUTH_MODE=google`, the matching `GOOGLE_CLIENT_ID`, `NAMELLO_SESSION_SECRET`, exact `CORS_ORIGINS`, and persistent storage if sync data must survive redeploys.
- Automated tests do not replace hands-on testing on an Android device. Validate SAF folder selection, backup/restore, notifications, Android Back, and Google OAuth on the target device before calling the release production-ready.


گزارش کامل ارزیابی، آزمون‌ها و موارد باقی‌مانده: [`AUDIT_FA.md`](AUDIT_FA.md).
