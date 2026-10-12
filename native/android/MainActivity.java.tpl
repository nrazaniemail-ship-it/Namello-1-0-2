package __PACKAGE__;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.ComponentName;
import android.content.pm.PackageManager;
import android.graphics.drawable.ColorDrawable;
import android.hardware.biometrics.BiometricManager;
import android.hardware.biometrics.BiometricPrompt;
import android.net.Uri;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.provider.MediaStore;
import android.provider.DocumentsContract;
import android.util.Base64;
import android.os.Build;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.provider.Settings;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.OutputStream;
import java.util.concurrent.Executor;

import androidx.core.content.ContextCompat;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.getcapacitor.BridgeActivity;

/**
 * Namello - Capacitor host activity (generated from native/android/MainActivity.java.tpl).
 *
 * Navigation-bar handling with two modes chosen by the user in Settings -> "Navigation bar":
 *
 *   "separate" (default, "جدایش") : the content view is padded by the navigation-bar / cut-out /
 *                                    keyboard insets, so the bottom tab bar sits ABOVE the system
 *                                    navigation bar and never collides with it.
 *   "overlap"  ("تداخل")           : the page is drawn full-screen under the navigation bar (only the
 *                                    keyboard still resizes the page).
 *
 * The chosen mode is stored natively (SharedPreferences) so it is applied at start-up before the page
 * has loaded. The page changes it with window.NamelloAndroid.setNavBarMode("separate" | "overlap").
 * Launcher icon: scripts/configure-android.mjs declares one <activity-alias> per fixed theme and one per
 * weekday; the page switches with setLauncherIcon(key) (fixed) / setWeeklyIcon(true|false) (daily change,
 * see IconThemeHelper + DailyIconReceiver).
 * App lock: canAuthenticate()/authenticate() show the system fingerprint / face / device-PIN prompt
 * (android.hardware.biometrics.BiometricPrompt, Android 9+); the result is delivered to the page through
 * window.__nmAuthResult(status). setSecureScreen() hides the app in Recents and blocks screenshots.
 * File export: saveToDownloads() stores Excel/CSV/JSON files in the public Download folder and
 * openUri() opens them; printHtml() opens Android's print dialog ("Save as PDF") for PDF reports.
 * (The WebView can neither download blob: files nor call window.print().)
 * Floating "return to Namello" button over other apps: FloatingReturnService (see that class).
 * It also exposes launchApp(pkg, scheme) for the floating MT5 / TradingView quick-launch buttons
 * (intent:// links do not work inside a WebView, PackageManager does).
 * Insets are consumed so nothing is ever padded twice; the status-bar height is given to the page as
 * --nm-safe-top and the navigation-bar height as --nm-nav-height.
 */
public class MainActivity extends BridgeActivity {

    private static final int BACKGROUND = 0xFF0B0E11;
    private static final String PREFS = "namello_native";
    private static final String KEY_NAV_MODE = "navbar_mode";
    private static final String MODE_SEPARATE = "separate";
    private static final String MODE_OVERLAP = "overlap";
    private static final String KEY_SECURE = "secure_screen";

    private volatile boolean separate = true;
    private WebView printWebView;   // kept alive while the print dialog is open
    private int topInsetPx = 0;
    private int navInsetPx = 0;
    private static final int REQ_BACKUP_TREE = 7412;
    private static final String KEY_BACKUP_TREE_URI = "backup_tree_uri";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            String saved = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_NAV_MODE, MODE_SEPARATE);
            separate = !MODE_OVERLAP.equals(saved);
            if (getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_SECURE, false)) {
                getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
            }

            // colour of the strip that appears behind the navigation bar in "separate" mode
            getWindow().setBackgroundDrawable(new ColorDrawable(BACKGROUND));
            if (Build.VERSION.SDK_INT >= 29) {
                getWindow().setNavigationBarContrastEnforced(false); // no grey scrim behind 3-button nav
            }
            WindowInsetsControllerCompat controller =
                    WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
            if (controller != null) {
                controller.setAppearanceLightNavigationBars(false);
            }

            View content = findViewById(android.R.id.content);
            if (content != null) {
                ViewCompat.setOnApplyWindowInsetsListener(content, (view, windowInsets) -> {
                    Insets bars = windowInsets.getInsets(
                            WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
                    Insets keyboard = windowInsets.getInsets(WindowInsetsCompat.Type.ime());
                    int bottom = separate ? Math.max(bars.bottom, keyboard.bottom) : keyboard.bottom;
                    view.setPadding(bars.left, 0, bars.right, bottom);
                    topInsetPx = bars.top;
                    navInsetPx = bars.bottom;
                    pushInsetsToPage();
                    return WindowInsetsCompat.CONSUMED;
                });
                ViewCompat.requestApplyInsets(content);
            }

            WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
            if (webView != null) {
                webView.addJavascriptInterface(new NamelloAndroid(), "NamelloAndroid");
            }
        } catch (Throwable ignored) {
            // never block app start-up because of cosmetic inset handling
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_BACKUP_TREE) return;
        try {
            if (resultCode == RESULT_OK && data != null && data.getData() != null) {
                Uri tree = data.getData();
                int flags = data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                getContentResolver().takePersistableUriPermission(tree, flags);
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_BACKUP_TREE_URI, tree.toString()).apply();
                String name = "پوشه‌ی انتخاب‌شده";
                try {
                    android.database.Cursor c = getContentResolver().query(tree, new String[]{DocumentsContract.Document.COLUMN_DISPLAY_NAME}, null, null, null);
                    if (c != null) { try { if (c.moveToFirst()) name = c.getString(0); } finally { c.close(); } }
                } catch (Throwable ignored) { }
                final String safeName = name.replace("\\", "\\\\").replace("'", "\\'");
                final String uriText = tree.toString().replace("\\", "\\\\").replace("'", "\\'");
                final WebView web = (getBridge() != null) ? getBridge().getWebView() : null;
                if (web != null) web.post(() -> web.evaluateJavascript("window.__nmBackupFolderResult && window.__nmBackupFolderResult(true,'" + safeName + "','" + uriText + "')", null));
                return;
            }
        } catch (Throwable ignored) { }
        final WebView web = (getBridge() != null) ? getBridge().getWebView() : null;
        if (web != null) web.post(() -> web.evaluateJavascript("window.__nmBackupFolderResult && window.__nmBackupFolderResult(false,'','')", null));
    }

    private long lastBackPressAt = 0L;

    /** Delegate Android system Back to the page first so dialogs and sub-layers close in order. */
    @Override
    public void onBackPressed() {
        try {
            final WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
            if (webView != null) {
                webView.evaluateJavascript("(function(){try{return window.__nmNativeBack?window.__nmNativeBack():'exit'}catch(e){return 'exit'}})()", value -> {
                    String result = value == null ? "\"exit\"" : value;
                    if (result.contains("handled")) return;
                    long now = System.currentTimeMillis();
                    if (now - lastBackPressAt < 1800L) {
                        lastBackPressAt = 0L;
                        finish();
                    } else {
                        lastBackPressAt = now;
                        toastToPage("برای خروج، دوباره دکمه‌ی بازگشت را بزنید.");
                    }
                });
                return;
            }
        } catch (Throwable ignored) { }
        super.onBackPressed();
    }

    @Override
    public void onStart() {
        super.onStart();
        FloatingReturnService.setAppForeground(true);   // floating button is hidden while Namello is visible
        try {
            if (IconThemeHelper.isWeekly(this)) {       // weekly icon theme: make sure today's icon + the midnight alarm are set
                IconThemeHelper.apply(this);
                IconThemeHelper.scheduleNext(this);
            }
        } catch (Throwable ignored) {
        }
    }

    @Override
    public void onStop() {
        super.onStop();
        FloatingReturnService.setAppForeground(false);  // ... and shown over other apps once we leave
    }

    private void applyLauncherIcon(String key) {
        if (!IconThemeHelper.isValidTheme(key)) return;
        IconThemeHelper.saveFixedTheme(this, key);        // remembered for the fixed theme / floating button
        IconThemeHelper.apply(this);                       // (does nothing visible while the weekly theme is on)
        FloatingReturnService.refreshIcon();
    }

    private void applyWeeklyIcon(boolean weekly) {
        IconThemeHelper.saveWeekly(this, weekly);
        IconThemeHelper.apply(this);
        IconThemeHelper.scheduleNext(this);                // schedules the midnight alarm, or cancels it
        FloatingReturnService.refreshIcon();
    }

    private boolean canDrawOverlays() {
        return Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this);
    }

    private void startFloatingService() {
        try {
            startService(new Intent(this, FloatingReturnService.class));   // plain service: no notification
        } catch (Throwable ignored) {
        }
    }

    private void sendAuthResult(final String status) {
        try {
            final WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
            if (webView == null) return;
            final String js = "window.__nmAuthResult && window.__nmAuthResult('" + status + "');";
            webView.post(() -> webView.evaluateJavascript(js, null));
        } catch (Throwable ignored) {
        }
    }

    private boolean biometricAvailable() {
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                BiometricManager manager = getSystemService(BiometricManager.class);
                return manager != null && manager.canAuthenticate(
                        BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                        == BiometricManager.BIOMETRIC_SUCCESS;
            }
            if (Build.VERSION.SDK_INT >= 29) {
                BiometricManager manager = getSystemService(BiometricManager.class);
                return manager != null && manager.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS;
            }
            if (Build.VERSION.SDK_INT >= 28) {
                return getPackageManager().hasSystemFeature(PackageManager.FEATURE_FINGERPRINT);
            }
        } catch (Throwable ignored) {
        }
        return false;
    }

    private void startAuthentication(String title, String subtitle) {
        if (Build.VERSION.SDK_INT < 28) {
            sendAuthResult("unsupported");
            return;
        }
        try {
            final Executor executor = ContextCompat.getMainExecutor(this);
            BiometricPrompt.Builder builder = new BiometricPrompt.Builder(this)
                    .setTitle(title == null || title.isEmpty() ? "Namello" : title);
            if (subtitle != null && !subtitle.isEmpty()) builder.setSubtitle(subtitle);
            if (Build.VERSION.SDK_INT >= 30) {
                // fingerprint / face / device PIN-pattern-password in one prompt
                builder.setAllowedAuthenticators(
                        BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.DEVICE_CREDENTIAL);
            } else {
                builder.setNegativeButton("استفاده از PIN", executor, (dialog, which) -> sendAuthResult("cancel"));
            }
            BiometricPrompt prompt = builder.build();
            prompt.authenticate(new CancellationSignal(), executor, new BiometricPrompt.AuthenticationCallback() {
                @Override
                public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) {
                    sendAuthResult("ok");
                }

                @Override
                public void onAuthenticationError(int errorCode, CharSequence errString) {
                    sendAuthResult("error");
                }
            });
        } catch (Throwable t) {
            sendAuthResult("error");
        }
    }

    private void pushInsetsToPage() {
        try {
            final WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
            if (webView == null) return;
            final float density = getResources().getDisplayMetrics().density;
            final String js = "(function(){var s=document.documentElement.style;"
                    + "s.setProperty('--nm-safe-top','" + (topInsetPx / density) + "px');"
                    + "s.setProperty('--nm-nav-height','" + (navInsetPx / density) + "px');})();";
            webView.post(() -> webView.evaluateJavascript(js, null));
        } catch (Throwable ignored) {
        }
    }

    /** Shows a message in the page's toast (the page listens for the "namello-toast" event). */
    private void toastToPage(String message) {
        try {
            final WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
            if (webView == null) return;
            final String js = "window.dispatchEvent(new CustomEvent('namello-toast',{detail:'" + message.replace("'", " ") + "'}));";
            webView.post(() -> webView.evaluateJavascript(js, null));
        } catch (Throwable ignored) {
        }
    }

    private void applyNavBarMode(String mode) {
        separate = !MODE_OVERLAP.equals(mode);
        View content = findViewById(android.R.id.content);
        if (content != null) ViewCompat.requestApplyInsets(content);
    }

    /** Methods callable from the page as window.NamelloAndroid.* */
    public class NamelloAndroid {
        @JavascriptInterface
        public void setNavBarMode(final String mode) {
            final String safe = MODE_OVERLAP.equals(mode) ? MODE_OVERLAP : MODE_SEPARATE;
            SharedPreferences.Editor editor = getSharedPreferences(PREFS, MODE_PRIVATE).edit();
            editor.putString(KEY_NAV_MODE, safe).apply();
            runOnUiThread(() -> applyNavBarMode(safe));
        }

        @JavascriptInterface
        public String getNavBarMode() {
            return separate ? MODE_SEPARATE : MODE_OVERLAP;
        }

        @JavascriptInterface
        public void setLauncherIcon(final String key) {
            runOnUiThread(() -> applyLauncherIcon(key));
        }

        @JavascriptInterface
        public boolean canAuthenticate() {
            return biometricAvailable();
        }

        /** Shows the system prompt; the result arrives as window.__nmAuthResult("ok" | "cancel" | "error" | "unsupported"). */
        @JavascriptInterface
        public void authenticate(final String title, final String subtitle) {
            runOnUiThread(() -> startAuthentication(title, subtitle));
        }

        /** Hides the app content in the Recents screen and blocks screenshots (FLAG_SECURE); remembered across launches. */
        @JavascriptInterface
        public void setSecureScreen(final boolean secure) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_SECURE, secure).apply();
            runOnUiThread(() -> {
                try {
                    if (secure) {
                        getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
                    } else {
                        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                    }
                } catch (Throwable ignored) {
                }
            });
        }

        @JavascriptInterface
        public void setWeeklyIcon(final boolean weekly) {
            runOnUiThread(() -> applyWeeklyIcon(weekly));
        }

        @JavascriptInterface
        public boolean hasOverlayPermission() {
            return canDrawOverlays();
        }

        /** true = floating button started; false = the "display over other apps" screen was opened instead. */
        @JavascriptInterface
        public boolean enableFloatingReturn() {
            if (!canDrawOverlays()) {
                runOnUiThread(() -> {
                    try {
                        Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:" + getPackageName()));
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        startActivity(intent);
                    } catch (Throwable ignored) {
                    }
                });
                return false;
            }
            runOnUiThread(() -> startFloatingService());
            return true;
        }

        /** Re-starts the button after the app was killed / the phone rebooted; never opens settings. */
        @JavascriptInterface
        public boolean restoreFloatingReturn() {
            if (!canDrawOverlays()) return false;
            runOnUiThread(() -> startFloatingService());
            return true;
        }

        @JavascriptInterface
        public void disableFloatingReturn() {
            runOnUiThread(() -> {
                try {
                    stopService(new Intent(MainActivity.this, FloatingReturnService.class));
                } catch (Throwable ignored) {
                }
            });
        }

        /** Launches Android's Storage Access Framework folder picker and remembers its persistent URI. */
        @JavascriptInterface
        public void pickBackupFolder() {
            runOnUiThread(() -> {
                try {
                    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
                    startActivityForResult(intent, REQ_BACKUP_TREE);
                } catch (Throwable t) {
                    final WebView web = (getBridge() != null) ? getBridge().getWebView() : null;
                    if (web != null) web.post(() -> web.evaluateJavascript("window.__nmBackupFolderResult && window.__nmBackupFolderResult(false,'','')", null));
                }
            });
        }

        @JavascriptInterface
        public boolean hasPickedBackupFolder() {
            return !getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_BACKUP_TREE_URI, "").isEmpty();
        }

        /** Writes a backup JSON into the SAF folder selected by the user. */
        @JavascriptInterface
        public String saveToPickedBackupFolder(String fileName, String mime, String base64) {
            try {
                String treeText = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_BACKUP_TREE_URI, "");
                if (treeText.isEmpty()) return "no-folder";
                Uri tree = Uri.parse(treeText);
                String name = (fileName == null ? "Namello-backup.json" : fileName).replaceAll("[\\\\/:*?\"<>|]", "_");
                Uri dir = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree));
                Uri file = DocumentsContract.createDocument(getContentResolver(), dir, (mime == null || mime.isEmpty()) ? "application/json" : mime, name);
                if (file == null) return "error:create";
                byte[] bytes = Base64.decode(base64, Base64.DEFAULT);
                OutputStream out = getContentResolver().openOutputStream(file, "w");
                if (out == null) return "error:stream";
                try { out.write(bytes); } finally { out.close(); }
                return "ok|" + name + "|" + file.toString();
            } catch (Throwable t) { return "error:" + t.getClass().getSimpleName(); }
        }

        /**
         * Saves a file into the public Download folder (Android 10+, no permission needed).
         * Returns "ok|name|uri", "unsupported" (Android 9 or older) or "error:...".
         */
        @JavascriptInterface
        public String saveToDownloads(String fileName, String mime, String base64) {
            if (Build.VERSION.SDK_INT < 29) return "unsupported";
            try {
                String name = (fileName == null ? "" : fileName).replaceAll("[\\\\/:*?\"<>|]", "_").trim();
                if (name.isEmpty()) name = "namello-export";
                byte[] data = Base64.decode(base64, Base64.DEFAULT);
                ContentValues values = new ContentValues();
                values.put(MediaStore.Downloads.DISPLAY_NAME, name);
                values.put(MediaStore.Downloads.MIME_TYPE, (mime == null || mime.isEmpty()) ? "application/octet-stream" : mime);
                values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS);
                values.put(MediaStore.Downloads.IS_PENDING, 1);
                ContentResolver resolver = getContentResolver();
                Uri uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                if (uri == null) return "error:insert";
                OutputStream out = resolver.openOutputStream(uri);
                if (out == null) return "error:stream";
                try {
                    out.write(data);
                } finally {
                    out.close();
                }
                ContentValues done = new ContentValues();
                done.put(MediaStore.Downloads.IS_PENDING, 0);
                resolver.update(uri, done, null, null);
                return "ok|" + name + "|" + uri.toString();
            } catch (Throwable t) {
                return "error:" + t.getClass().getSimpleName();
            }
        }

        /**
         * Same as saveToDownloads but inside Download/<subDir> (e.g. Download/Namello-Backups).
         * Returns "ok|name|uri", "unsupported" or "error:...".
         */
        @JavascriptInterface
        public String saveToDownloadsIn(String subDir, String fileName, String mime, String base64) {
            if (Build.VERSION.SDK_INT < 29) return "unsupported";
            try {
                String dir = (subDir == null ? "" : subDir).replaceAll("[^A-Za-z0-9_\\-]", "").trim();
                String name = (fileName == null ? "" : fileName).replaceAll("[\\\\/:*?\"<>|]", "_").trim();
                if (name.isEmpty()) name = "namello-export";
                byte[] data = Base64.decode(base64, Base64.DEFAULT);
                ContentValues values = new ContentValues();
                values.put(MediaStore.Downloads.DISPLAY_NAME, name);
                values.put(MediaStore.Downloads.MIME_TYPE, (mime == null || mime.isEmpty()) ? "application/octet-stream" : mime);
                values.put(MediaStore.Downloads.RELATIVE_PATH, dir.isEmpty() ? Environment.DIRECTORY_DOWNLOADS : Environment.DIRECTORY_DOWNLOADS + "/" + dir);
                values.put(MediaStore.Downloads.IS_PENDING, 1);
                ContentResolver resolver = getContentResolver();
                Uri uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                if (uri == null) return "error:insert";
                OutputStream out = resolver.openOutputStream(uri);
                if (out == null) return "error:stream";
                try {
                    out.write(data);
                } finally {
                    out.close();
                }
                ContentValues done = new ContentValues();
                done.put(MediaStore.Downloads.IS_PENDING, 0);
                resolver.update(uri, done, null, null);
                return "ok|" + name + "|" + uri.toString();
            } catch (Throwable t) {
                return "error:" + t.getClass().getSimpleName();
            }
        }

        /**
         * Keeps only the newest `keep` files named prefix* in Download/<subDir> that THIS app created
         * (older ones are deleted). Returns the number of deleted files, or -1 on error.
         */
        @JavascriptInterface
        public int pruneDownloads(String subDir, String prefix, int keep) {
            if (Build.VERSION.SDK_INT < 29) return -1;
            try {
                String dir = (subDir == null ? "" : subDir).replaceAll("[^A-Za-z0-9_\\-]", "").trim();
                if (dir.isEmpty() || keep < 1) return -1;
                ContentResolver resolver = getContentResolver();
                String[] projection = {MediaStore.Downloads._ID};
                String selection = MediaStore.Downloads.RELATIVE_PATH + " LIKE ? AND " + MediaStore.Downloads.DISPLAY_NAME + " LIKE ?";
                String[] args = {Environment.DIRECTORY_DOWNLOADS + "/" + dir + "%", (prefix == null ? "" : prefix) + "%"};
                int deleted = 0;
                android.database.Cursor cursor = resolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, projection, selection, args,
                        MediaStore.Downloads.DATE_ADDED + " DESC");
                if (cursor == null) return -1;
                try {
                    int index = 0;
                    while (cursor.moveToNext()) {
                        index++;
                        if (index <= keep) continue;
                        Uri item = Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, String.valueOf(cursor.getLong(0)));
                        try {
                            deleted += resolver.delete(item, null, null);
                        } catch (Throwable ignored) {
                        }
                    }
                } finally {
                    cursor.close();
                }
                return deleted;
            } catch (Throwable t) {
                return -1;
            }
        }

        /** Opens a saved file with an app chosen by the user (Excel, PDF viewer ...). */
        @JavascriptInterface
        public boolean openUri(final String uriString, final String mime) {
            try {
                final Intent view = new Intent(Intent.ACTION_VIEW);
                view.setDataAndType(Uri.parse(uriString), (mime == null || mime.isEmpty()) ? "*/*" : mime);
                view.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                final Intent chooser = Intent.createChooser(view, "باز کردن با…");
                runOnUiThread(() -> {
                    try {
                        startActivity(chooser);
                    } catch (Throwable ignored) {
                    }
                });
                return true;
            } catch (Throwable t) {
                return false;
            }
        }

        /** Opens Android's print dialog for an HTML report; the user picks "Save as PDF". */
        @JavascriptInterface
        public boolean printHtml(final String html, final String jobName) {
            if (html == null || html.isEmpty()) return false;
            final String job = (jobName == null || jobName.trim().isEmpty()) ? "Namello" : jobName.trim();
            runOnUiThread(() -> {
                try {
                    final WebView web = new WebView(MainActivity.this);
                    printWebView = web;
                    web.setWebViewClient(new WebViewClient() {
                        private boolean started = false;

                        @Override
                        public void onPageFinished(final WebView view, String url) {
                            if (started) return;
                            started = true;
                            // short delay so the web font and logo can finish loading.
                            // NOTE: a Handler is required - View.postDelayed() never runs for a WebView that is
                            // not attached to a window (that was why no print dialog appeared).
                            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                                try {
                                    PrintManager manager = (PrintManager) getSystemService(Context.PRINT_SERVICE);
                                    PrintDocumentAdapter adapter = view.createPrintDocumentAdapter(job);
                                    PrintAttributes attributes = new PrintAttributes.Builder()
                                            .setMediaSize(PrintAttributes.MediaSize.ISO_A4.asLandscape())
                                            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                                            .build();
                                    manager.print(job, adapter, attributes);
                                } catch (Throwable t) {
                                    toastToPage("باز کردن پنجره‌ی چاپ ناموفق بود.");
                                }
                            }, 900);
                        }
                    });
                    web.loadDataWithBaseURL("https://localhost/", html, "text/html", "UTF-8", null);
                } catch (Throwable ignored) {
                }
            });
            return true;
        }

        /**
         * Opens an installed app. Returns "ok" (package launched), "scheme" (custom link tried),
         * "notfound" (nothing to launch) or "error".
         */
        @JavascriptInterface
        public String launchApp(final String pkg, final String scheme) {
            try {
                PackageManager pm = getPackageManager();
                String name = (pkg == null) ? "" : pkg.trim();
                Intent launch = name.isEmpty() ? null : pm.getLaunchIntentForPackage(name);
                if (launch != null) {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    final Intent toStart = launch;
                    runOnUiThread(() -> {
                        try {
                            startActivity(toStart);
                        } catch (Throwable ignored) {
                        }
                    });
                    return "ok";
                }
                String link = (scheme == null) ? "" : scheme.trim();
                if (!link.isEmpty()) {
                    final Intent view = new Intent(Intent.ACTION_VIEW, Uri.parse(link));
                    view.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    runOnUiThread(() -> {
                        try {
                            startActivity(view);
                        } catch (Throwable ignored) {
                        }
                    });
                    return "scheme";
                }
                return "notfound";
            } catch (Throwable t) {
                return "error";
            }
        }

        /** Status-bar height in CSS pixels, for --nm-safe-top. */
        @JavascriptInterface
        public String getTopInset() {
            return String.valueOf(topInsetPx / getResources().getDisplayMetrics().density);
        }
    }
}
