package __PACKAGE__;

import android.content.Intent;
import android.content.SharedPreferences;
import android.content.ComponentName;
import android.content.pm.PackageManager;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

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
 * Launcher icon theme: scripts/configure-android.mjs declares one <activity-alias> per theme; the page
 * switches between them with setLauncherIcon(key).
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
    /** Must match NM_ICON_THEMES keys in index.html and the aliases written by configure-android.mjs. */
    private static final String[] ICON_KEYS = {"default", "midnight", "emerald", "royal", "graphite", "sunset", "ruby"};

    private volatile boolean separate = true;
    private int topInsetPx = 0;
    private int navInsetPx = 0;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            String saved = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_NAV_MODE, MODE_SEPARATE);
            separate = !MODE_OVERLAP.equals(saved);

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
    public void onStart() {
        super.onStart();
        FloatingReturnService.setAppForeground(true);   // floating button is hidden while Namello is visible
    }

    @Override
    public void onStop() {
        super.onStop();
        FloatingReturnService.setAppForeground(false);  // ... and shown over other apps once we leave
    }

    private void applyLauncherIcon(String key) {
        boolean known = false;
        for (String k : ICON_KEYS) if (k.equals(key)) known = true;
        if (!known) return;
        String className = getClass().getName();
        String namespace = className.substring(0, className.lastIndexOf('.'));
        PackageManager pm = getPackageManager();
        // enable the wanted alias first so the app never has zero launcher entries, then disable the rest
        for (int pass = 0; pass < 2; pass++) {
            for (String k : ICON_KEYS) {
                boolean wanted = k.equals(key);
                if (wanted != (pass == 0)) continue;
                String alias = namespace + ".Launcher" + Character.toUpperCase(k.charAt(0)) + k.substring(1);
                try {
                    pm.setComponentEnabledSetting(
                            new ComponentName(getPackageName(), alias),
                            wanted ? PackageManager.COMPONENT_ENABLED_STATE_ENABLED : PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP);
                } catch (Throwable ignored) {
                }
            }
        }
    }

    private boolean canDrawOverlays() {
        return Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this);
    }

    private void startFloatingService() {
        try {
            ContextCompat.startForegroundService(this, new Intent(this, FloatingReturnService.class));
        } catch (Throwable ignored) {
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
