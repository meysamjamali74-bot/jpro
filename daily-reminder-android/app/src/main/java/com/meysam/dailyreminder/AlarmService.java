package com.meysam.dailyreminder;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.RingtoneManager;
import android.media.ToneGenerator;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.os.VibrationEffect;
import android.os.Vibrator;

public class AlarmService extends Service {
    private static final String CHANNEL = "daily_reminder_alarm_v2";
    private final Handler handler = new Handler(Looper.getMainLooper());
    private ToneGenerator tone;
    private MediaPlayer player;
    private PowerManager.WakeLock wakeLock;
    private Vibrator vibrator;
    private boolean running;

    @Override public void onCreate() {
        super.onCreate();
        NotificationManager nm = getSystemService(NotificationManager.class);
        NotificationChannel channel = new NotificationChannel(CHANNEL,
            "زنگ‌های یادآور روزانه", NotificationManager.IMPORTANCE_HIGH);
        channel.setDescription("آلارم پنج ثانیه‌ای");
        channel.setSound(null, null);
        channel.enableVibration(false);
        if (nm != null) nm.createNotificationChannel(channel);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (running) return START_NOT_STICKY;
        running = true;
        Diagnostics.write(this, "SERVICE_STARTED");
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
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(17, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            } else startForeground(17, notification);
        } catch (Exception ex) {
            Diagnostics.write(this, "FOREGROUND_ERROR " + ex.getClass().getSimpleName());
        }
        startSound();
        handler.postDelayed(this::stopSelf, 5000);
        return START_NOT_STICKY;
    }

    private void startSound() {
        try {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DailyReminder:Alarm");
            wakeLock.acquire(7000);
        } catch (Exception ex) {
            Diagnostics.write(this, "WAKELOCK_ERROR " + ex.getClass().getSimpleName());
        }
        try {
            vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator())
                vibrator.vibrate(VibrationEffect.createOneShot(5000, VibrationEffect.DEFAULT_AMPLITUDE));
        } catch (Exception ex) {
            Diagnostics.write(this, "VIBRATE_ERROR " + ex.getClass().getSimpleName());
        }

        AudioManager audio = (AudioManager) getSystemService(AUDIO_SERVICE);
        if (audio != null) Diagnostics.write(this,
            "ALARM_VOLUME " + audio.getStreamVolume(AudioManager.STREAM_ALARM)
                + "/" + audio.getStreamMaxVolume(AudioManager.STREAM_ALARM));

        try {
            Uri alarm = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM);
            if (alarm == null) alarm = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
            if (alarm == null) throw new IllegalStateException("No alarm ringtone");
            player = new MediaPlayer();
            player.setAudioAttributes(new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build());
            player.setDataSource(this, alarm);
            player.setLooping(true);
            player.prepare();
            player.start();
            Diagnostics.write(this, "RINGTONE_PLAYING");
        } catch (Exception ex) {
            Diagnostics.write(this, "RINGTONE_ERROR " + ex.getClass().getSimpleName());
            try {
                if (player != null) { player.release(); player = null; }
                tone = new ToneGenerator(AudioManager.STREAM_ALARM, 100);
                for (int i = 0; i < 5; i++) {
                    handler.postDelayed(() -> {
                        if (tone != null) tone.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 800);
                    }, i * 1000L);
                }
                Diagnostics.write(this, "FALLBACK_BEEP");
            } catch (Exception e) {
                Diagnostics.write(this, "AUDIO_ERROR " + e.getClass().getSimpleName());
            }
        }
    }

    @Override public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        try { if (player != null) { player.stop(); player.release(); player = null; } }
        catch (Exception ignored) { }
        try { if (tone != null) { tone.stopTone(); tone.release(); tone = null; } }
        catch (Exception ignored) { }
        try { if (vibrator != null) vibrator.cancel(); } catch (Exception ignored) { }
        try { if (wakeLock != null && wakeLock.isHeld()) wakeLock.release(); } catch (Exception ignored) { }
        Diagnostics.write(this, "SERVICE_STOPPED");
        running = false;
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }
}
