# Namello 1.0.2

PWA trading journal with broker CSV templates/import guide, virtualized statement lists, psychology metrics, multi-account portfolio view, Prop Firm rules, MT5/TradingView OHLC replay, stronger Sync conflict resolution, and a gradual TypeScript/Vite migration scaffold.

The runtime remains compatible with the existing single-file PWA architecture while pure logic is being extracted under `src/modules/`.

## Firebase Authentication (Namello 1.0.2)

The Security / Backup settings include Firebase email/password registration and login plus Google sign-in through Firebase Authentication. Configure these values in the app's security settings:

- Firebase Project ID (for example `namello-app-4`)
- Firebase Web API Key from Project settings → General → Your apps → SDK setup and configuration
- Google OAuth Web Client ID

In Firebase Console → Authentication → Sign-in method, enable **Email/Password** and **Google**. In the backend deployment, set `FIREBASE_PROJECT_ID` and `FIREBASE_WEB_API_KEY` to the same Firebase project values, and configure `NAMELLO_AUTH_MODE=google`, `GOOGLE_CLIENT_ID`, and a strong `NAMELLO_SESSION_SECRET` (at least 32 characters). Do not put service-account private keys in the web app or repository. The web API key is a public client identifier; restrict it appropriately in Google Cloud while allowing Identity Toolkit API.

The backend `/v1/auth/firebase/verify` endpoint validates the Firebase ID token through Firebase Identity Toolkit before issuing a Namello session. Real provider sign-in still requires the project settings above and should be tested against the deployed Firebase/Render environment.
