package __PACKAGE__;

import android.content.SharedPreferences;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

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
 * Insets are consumed so nothing is ever padded twice; the status-bar height is given to the page as
 * --nm-safe-top and the navigation-bar height as --nm-nav-height.
 */
public class MainActivity extends BridgeActivity {

    private static final int BACKGROUND = 0xFF0B0E11;
    private static final String PREFS = "namello_native";
    private static final String KEY_NAV_MODE = "navbar_mode";
    private static final String MODE_SEPARATE = "separate";
    private static final String MODE_OVERLAP = "overlap";

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

        /** Status-bar height in CSS pixels, for --nm-safe-top. */
        @JavascriptInterface
        public String getTopInset() {
            return String.valueOf(topInsetPx / getResources().getDisplayMetrics().density);
        }
    }
}
