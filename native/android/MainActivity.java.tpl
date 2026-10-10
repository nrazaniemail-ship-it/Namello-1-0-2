package __PACKAGE__;

import android.annotation.SuppressLint;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import androidx.activity.OnBackPressedCallback;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.getcapacitor.BridgeActivity;

/**
 * Namello – Capacitor host activity (generated from native/android/MainActivity.java.tpl).
 *
 * 1. Edge-to-edge: from Android 15 the WebView is drawn under the system navigation bar.
 *    The content view is padded by the bottom/left/right system-bar (and keyboard) insets so the
 *    app's bottom tab bar can never overlap the 3-button / gesture navigation bar.
 * 2. Back button: the in-app layer logic (window.__nmNativeBack in index.html) decides what Back
 *    does (close dialog -> previous layer -> double-press to exit) instead of leaving the app.
 * 3. "Return to Namello" notification: shown natively when the app goes to the background (the web
 *    Notification API is not available in the WebView) and removed when the app comes back.
 * 4. Launcher icon theme: one <activity-alias> per theme is declared in the manifest by
 *    scripts/configure-android.mjs; the page switches between them with setLauncherIcon().
 * 5. A tiny JavaScript interface (NamelloAndroid) lets the page tell the system bars which
 *    colour to use so they follow the app's light / dark theme.
 */
public class MainActivity extends BridgeActivity {

    private static final int DEFAULT_BAR_COLOR = 0xFF0B0E11;
    private static final String PREFS = "namello_native";
    private static final String KEY_RETURN = "return_notification";
    private static final String RETURN_CHANNEL = "namello-return-v2";
    private static final int RETURN_NOTIFICATION_ID = 424242;
    /** Must match NM_ICON_THEMES keys in index.html and the aliases written by configure-android.mjs. */
    private static final String[] ICON_KEYS = {"default", "midnight", "emerald", "royal", "graphite", "sunset", "ruby"};

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        installInsetsHandling();
        installBackHandling();
        installJavascriptInterface();
        applyBarColor(DEFAULT_BAR_COLOR);
    }

    @Override
    public void onStart() {
        super.onStart();
        try {
            NotificationManagerCompat.from(this).cancel(RETURN_NOTIFICATION_ID);
        } catch (Throwable ignored) {
        }
    }

    @Override
    public void onStop() {
        super.onStop();
        showReturnNotificationIfEnabled();
    }

    @SuppressLint("MissingPermission")
    private void showReturnNotificationIfEnabled() {
        try {
            if (!getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_RETURN, false)) return;
            if (isChangingConfigurations() || isFinishing()) return;
            NotificationManagerCompat manager = NotificationManagerCompat.from(this);
            if (!manager.areNotificationsEnabled()) return;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationChannel channel = new NotificationChannel(
                        RETURN_CHANNEL, "بازگشت به Namello", NotificationManager.IMPORTANCE_LOW);
                channel.setShowBadge(false);
                NotificationManager system = getSystemService(NotificationManager.class);
                if (system != null) system.createNotificationChannel(channel);
            }
            Intent launch = new Intent(this, MainActivity.class);
            launch.setAction(Intent.ACTION_MAIN);
            launch.addCategory(Intent.CATEGORY_LAUNCHER);
            launch.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            PendingIntent pending = PendingIntent.getActivity(
                    this, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            int icon = getResources().getIdentifier("ic_stat_namello", "drawable", getPackageName());
            if (icon == 0) icon = android.R.drawable.ic_dialog_info;
            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, RETURN_CHANNEL)
                    .setSmallIcon(icon)
                    .setContentTitle("Namello در پس‌زمینه فعاله")
                    .setContentText("برای بازگشت سریع به Namello ضربه بزن.")
                    .setContentIntent(pending)
                    .setAutoCancel(true)
                    .setOnlyAlertOnce(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW);
            manager.notify(RETURN_NOTIFICATION_ID, builder.build());
        } catch (Throwable ignored) {
        }
    }

    private void applyLauncherIcon(String key) {
        boolean known = false;
        for (String k : ICON_KEYS) if (k.equals(key)) known = true;
        if (!known) return;
        String className = getClass().getName();
        String namespace = className.substring(0, className.lastIndexOf('.'));
        PackageManager pm = getPackageManager();
        // enable the wanted alias first so the app never has zero launcher entries
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

    private void installInsetsHandling() {
        try {
            View content = findViewById(android.R.id.content);
            if (content == null) return;
            ViewCompat.setOnApplyWindowInsetsListener(content, (view, windowInsets) -> {
                int mask = WindowInsetsCompat.Type.systemBars()
                        | WindowInsetsCompat.Type.displayCutout()
                        | WindowInsetsCompat.Type.ime();
                Insets insets = windowInsets.getInsets(mask);
                // Top is intentionally untouched: the page already pads itself under the status bar.
                view.setPadding(insets.left, 0, insets.right, insets.bottom);
                return windowInsets;
            });
            ViewCompat.requestApplyInsets(content);
        } catch (Throwable ignored) {
            // Never block app start-up because of cosmetic inset handling.
        }
    }

    private void installBackHandling() {
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                final WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
                if (webView == null) {
                    finish();
                    return;
                }
                final String js = "(function(){try{return window.__nmNativeBack?String(window.__nmNativeBack()):'none';}catch(e){return 'none';}})()";
                webView.evaluateJavascript(js, value -> {
                    if (value != null && value.contains("handled")) {
                        return; // the page consumed the Back press
                    }
                    finish();   // page asked to exit (second press) or is not ready yet
                });
            }
        });
    }

    private void installJavascriptInterface() {
        try {
            WebView webView = (getBridge() != null) ? getBridge().getWebView() : null;
            if (webView != null) {
                webView.addJavascriptInterface(new NamelloAndroid(), "NamelloAndroid");
            }
        } catch (Throwable ignored) {
        }
    }

    private void applyBarColor(final int color) {
        try {
            getWindow().setBackgroundDrawable(new ColorDrawable(color));
            double luminance = (0.299 * Color.red(color) + 0.587 * Color.green(color) + 0.114 * Color.blue(color)) / 255.0;
            boolean lightBackground = luminance > 0.6;
            WindowInsetsControllerCompat controller =
                    WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
            if (controller != null) {
                controller.setAppearanceLightNavigationBars(lightBackground);
                controller.setAppearanceLightStatusBars(lightBackground);
            }
        } catch (Throwable ignored) {
        }
    }

    /** Methods callable from the page as window.NamelloAndroid.* */
    public class NamelloAndroid {
        @JavascriptInterface
        public void setReturnNotification(boolean enabled) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_RETURN, enabled).apply();
        }

        @JavascriptInterface
        public void setLauncherIcon(final String key) {
            runOnUiThread(() -> applyLauncherIcon(key));
        }

        @JavascriptInterface
        public void setChromeColor(final String hex) {
            if (hex == null) return;
            final int color;
            try {
                color = Color.parseColor(hex.trim());
            } catch (IllegalArgumentException e) {
                return;
            }
            runOnUiThread(() -> applyBarColor(color | 0xFF000000));
        }
    }
}
