package __PACKAGE__;

import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import android.view.View;
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
 * Only job: keep the page's bottom tab bar from sliding under the Android navigation bar.
 * From Android 15 the app is drawn edge-to-edge, so the content view is padded by the system-bar,
 * display-cut-out and keyboard insets (left / right / bottom) and those insets are consumed so nothing
 * is padded twice. The top is not padded (the page header already reserves that space); the
 * status-bar height is handed to the page as --nm-safe-top for the alarm pop-up.
 */
public class MainActivity extends BridgeActivity {

    private static final int BACKGROUND = 0xFF0B0E11;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            // colour of the strip that appears behind the navigation bar
            getWindow().setBackgroundDrawable(new ColorDrawable(BACKGROUND));
            WindowInsetsControllerCompat controller =
                    WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
            if (controller != null) {
                controller.setAppearanceLightNavigationBars(false);
            }
            View content = findViewById(android.R.id.content);
            if (content == null) return;
            ViewCompat.setOnApplyWindowInsetsListener(content, (view, windowInsets) -> {
                Insets bars = windowInsets.getInsets(
                        WindowInsetsCompat.Type.systemBars()
                                | WindowInsetsCompat.Type.displayCutout()
                                | WindowInsetsCompat.Type.ime());
                view.setPadding(bars.left, 0, bars.right, bars.bottom);
                Insets top = windowInsets.getInsets(
                        WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
                pushTopInset(top.top);
                return WindowInsetsCompat.CONSUMED;
            });
            ViewCompat.requestApplyInsets(content);
        } catch (Throwable ignored) {
            // never block app start-up because of cosmetic inset handling
        }
    }

    private void pushTopInset(int topPx) {
        try {
            final WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
            if (webView == null) return;
            final float density = getResources().getDisplayMetrics().density;
            final String js = "document.documentElement.style.setProperty('--nm-safe-top','"
                    + (topPx / density) + "px');";
            webView.post(() -> webView.evaluateJavascript(js, null));
        } catch (Throwable ignored) {
        }
    }
}
