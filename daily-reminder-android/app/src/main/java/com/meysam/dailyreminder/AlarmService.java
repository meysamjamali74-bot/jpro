package com.meysam.dailyreminder;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.os.VibrationEffect;
import android.os.Vibrator;

public class AlarmService extends Service {
    private static final String CHANNEL = "daily_reminder_alarm_v1";
    private final Handler handler = new Handler(Looper.getMainLooper());
    private ToneGenerator tone;
    private PowerManager.WakeLock wakeLock;
    private Vibrator vibrator;
    private boolean running;

    @Override public void onCreate() {
        super.onCreate();
        NotificationManager nm = getSystemService(NotificationManager.class);
        NotificationChannel channel = new NotificationChannel(CHANNEL, "یادآوری کارها", NotificationManager.IMPORTANCE_HIGH);
        channel.setDescription("زنگ پنج ثانیه ای کارهای روزانه");
        channel.setSound(null, null);
        channel.enableVibration(false);
        nm.createNotificationChannel(channel);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (running) return START_NOT_STICKY;
        running = true;
        String title = intent != null ? intent.getStringExtra("title") : null;
        if (title == null || title.trim().isEmpty()) title = "وقت انجام کار رسیده";
        Intent open = new Intent(this, MainActivity.class);
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pi = PendingIntent.getActivity(this, 1, open,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("یادآور روزانه")
            .setContentText(title)
            .setContentIntent(pi)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build();
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(17, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(17, notification);
        }

        try {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DailyReminder:FiveSecondAlarm");
            wakeLock.acquire(7000);
            vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator()) {
                vibrator.vibrate(VibrationEffect.createOneShot(5000, VibrationEffect.DEFAULT_AMPLITUDE));
            }
            tone = new ToneGenerator(AudioManager.STREAM_ALARM, 95);
            for (int i = 0; i < 5; i++) {
                final int delay = i * 1000;
                handler.postDelayed(() -> { if (tone != null) tone.startTone(ToneGenerator.TONE_PROP_BEEP, 700); }, delay);
            }
        } catch (Exception ignored) { }
        handler.postDelayed(this::stopSelf, 5000);
        return START_NOT_STICKY;
    }

    @Override public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        try { if (tone != null) { tone.stopTone(); tone.release(); tone = null; } } catch (Exception ignored) { }
        try { if (vibrator != null) vibrator.cancel(); } catch (Exception ignored) { }
        try { if (wakeLock != null && wakeLock.isHeld()) wakeLock.release(); } catch (Exception ignored) { }
        running = false;
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }
}
