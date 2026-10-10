package __PACKAGE__;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.graphics.Outline;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewOutlineProvider;
import android.view.WindowManager;
import android.widget.ImageView;

import androidx.core.app.NotificationCompat;

/**
 * Namello - floating "return to Namello" button that stays on top of other apps (MT5, TradingView ...).
 *
 *  - needs the "Display over other apps" permission (SYSTEM_ALERT_WINDOW), requested from Settings;
 *  - runs as a foreground service so Android keeps it alive while Namello is in the background;
 *  - hidden while Namello itself is on screen, shown as soon as the user leaves it;
 *  - can be dragged anywhere; it snaps to the nearest screen edge and remembers its position;
 *  - one tap brings Namello back to the front.
 * Started / stopped from the page through window.NamelloAndroid.enableFloatingReturn() / disableFloatingReturn().
 */
public class FloatingReturnService extends Service {

    private static final String PREFS = "namello_native";
    private static final String KEY_X = "floating_x";
    private static final String KEY_Y = "floating_y";
    private static final String CHANNEL = "namello-floating";
    private static final int NOTIFICATION_ID = 424243;

    private static volatile FloatingReturnService instance;
    private static volatile boolean appForeground = false;

    private final Handler main = new Handler(Looper.getMainLooper());
    private WindowManager windowManager;
    private ImageView button;
    private WindowManager.LayoutParams params;
    private int sizePx;

    /** Called by MainActivity: hide the button while Namello is visible, show it otherwise. */
    public static void setAppForeground(boolean foreground) {
        appForeground = foreground;
        final FloatingReturnService service = instance;
        if (service != null) {
            service.main.post(new Runnable() {
                @Override
                public void run() {
                    service.applyVisibility();
                }
            });
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        instance = this;
        startInForeground();
        if (button == null) {
            createButton();
        }
        applyVisibility();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        instance = null;
        removeButton();
        super.onDestroy();
    }

    private void startInForeground() {
        try {
            NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
                NotificationChannel channel = new NotificationChannel(
                        CHANNEL, "دکمه‌ی شناور Namello", NotificationManager.IMPORTANCE_LOW);
                channel.setShowBadge(false);
                manager.createNotificationChannel(channel);
            }
            Intent open = new Intent(this, MainActivity.class);
            open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            PendingIntent pending = PendingIntent.getActivity(
                    this, 0, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            int icon = getResources().getIdentifier("ic_stat_namello", "drawable", getPackageName());
            if (icon == 0) icon = android.R.drawable.ic_dialog_info;
            Notification notification = new NotificationCompat.Builder(this, CHANNEL)
                    .setSmallIcon(icon)
                    .setContentTitle("دکمه‌ی شناور Namello فعال است")
                    .setContentText("برای بازگشت سریع به Namello روی دکمه‌ی شناور بزن.")
                    .setContentIntent(pending)
                    .setOngoing(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .build();
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
            } else {
                startForeground(NOTIFICATION_ID, notification);
            }
        } catch (Throwable ignored) {
        }
    }

    private void createButton() {
        try {
            final float density = getResources().getDisplayMetrics().density;
            sizePx = (int) (52 * density);
            final int screenW = getResources().getDisplayMetrics().widthPixels;
            final int screenH = getResources().getDisplayMetrics().heightPixels;
            windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);

            ImageView view = new ImageView(this);
            int image = getResources().getIdentifier("namello_launcher", "drawable", getPackageName());
            if (image != 0) {
                view.setImageResource(image);
            } else {
                view.setImageResource(android.R.drawable.ic_menu_revert);
            }
            view.setScaleType(ImageView.ScaleType.CENTER_CROP);
            int pad = (int) (2 * density);
            view.setPadding(pad, pad, pad, pad);
            GradientDrawable ring = new GradientDrawable();
            ring.setShape(GradientDrawable.OVAL);
            ring.setColor(0xFF12161C);
            ring.setStroke((int) (2 * density), 0xFFD4A64A);
            view.setBackground(ring);
            view.setClipToOutline(true);
            view.setOutlineProvider(new ViewOutlineProvider() {
                @Override
                public void getOutline(View v, Outline outline) {
                    outline.setOval(0, 0, v.getWidth(), v.getHeight());
                }
            });
            view.setElevation(6 * density);
            view.setContentDescription("بازگشت به Namello");

            int type = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    : WindowManager.LayoutParams.TYPE_PHONE;
            params = new WindowManager.LayoutParams(
                    sizePx, sizePx, type,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT);
            params.gravity = Gravity.TOP | Gravity.START;
            SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
            params.x = prefs.getInt(KEY_X, screenW - sizePx);
            params.y = prefs.getInt(KEY_Y, (int) (screenH * 0.4f));

            view.setOnTouchListener(new DragListener());
            windowManager.addView(view, params);
            button = view;
        } catch (Throwable t) {
            // overlay permission revoked or window could not be added
            button = null;
            stopSelf();
        }
    }

    private void removeButton() {
        try {
            if (windowManager != null && button != null) {
                windowManager.removeView(button);
            }
        } catch (Throwable ignored) {
        }
        button = null;
    }

    private void applyVisibility() {
        if (button != null) {
            button.setVisibility(appForeground ? View.GONE : View.VISIBLE);
        }
    }

    private void openNamello() {
        try {
            Intent open = new Intent(this, MainActivity.class);
            open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                    | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            startActivity(open);
        } catch (Throwable ignored) {
        }
    }

    /** Tap = back to Namello, drag = move (snaps to the nearest edge). */
    private class DragListener implements View.OnTouchListener {
        private int startX;
        private int startY;
        private float touchX;
        private float touchY;
        private boolean moved;
        private final int slop = ViewConfiguration.get(FloatingReturnService.this).getScaledTouchSlop();

        @Override
        public boolean onTouch(View view, MotionEvent event) {
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    startX = params.x;
                    startY = params.y;
                    touchX = event.getRawX();
                    touchY = event.getRawY();
                    moved = false;
                    return true;
                case MotionEvent.ACTION_MOVE: {
                    int dx = (int) (event.getRawX() - touchX);
                    int dy = (int) (event.getRawY() - touchY);
                    if (Math.abs(dx) > slop || Math.abs(dy) > slop) {
                        moved = true;
                    }
                    if (moved) {
                        params.x = startX + dx;
                        params.y = startY + dy;
                        try {
                            windowManager.updateViewLayout(view, params);
                        } catch (Throwable ignored) {
                        }
                    }
                    return true;
                }
                case MotionEvent.ACTION_UP:
                    if (!moved) {
                        openNamello();
                    } else {
                        snapToEdge(view);
                    }
                    return true;
                default:
                    return false;
            }
        }

        private void snapToEdge(View view) {
            int screenW = getResources().getDisplayMetrics().widthPixels;
            int screenH = getResources().getDisplayMetrics().heightPixels;
            params.x = (params.x + sizePx / 2 < screenW / 2) ? 0 : screenW - sizePx;
            params.y = Math.max(0, Math.min(params.y, screenH - sizePx));
            try {
                windowManager.updateViewLayout(view, params);
            } catch (Throwable ignored) {
            }
            getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                    .putInt(KEY_X, params.x).putInt(KEY_Y, params.y).apply();
        }
    }
}
