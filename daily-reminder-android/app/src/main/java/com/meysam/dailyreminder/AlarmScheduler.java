package com.meysam.dailyreminder;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import org.json.JSONArray;
import org.json.JSONObject;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;

public final class AlarmScheduler {
    private static final String PREFS = "daily_reminder_native";
    private static final String KEY = "tasks";
    private AlarmScheduler() {}

    public static synchronized void sync(Context context, String json) {
        try {
            JSONArray incoming = new JSONArray(json);
            if (incoming.length() > 200) return;
            SharedPreferences p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            String previous = p.getString(KEY, "[]");
            if (previous.equals(json)) return;
            cancelAll(context, previous);
            p.edit().putString(KEY, json).apply();
            scheduleAll(context, json);
        } catch (Exception ignored) { }
    }

    public static synchronized void rescheduleAll(Context context) {
        String json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]");
        cancelAll(context, json);
        scheduleAll(context, json);
    }

    public static boolean scheduleTest(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return false;
        if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) return false;
        PendingIntent pi = pending(context, "native_alarm_test", "آزمایش زنگ پنج ثانیه‌ای", PendingIntent.FLAG_UPDATE_CURRENT);
        if (pi == null) return false;
        try {
            AlarmManager.AlarmClockInfo info = new AlarmManager.AlarmClockInfo(
                System.currentTimeMillis() + 60000, PendingIntent.getActivity(context, 30,
                new Intent(context, MainActivity.class),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
            am.setAlarmClock(info, pi);
            Diagnostics.write(context, "TEST_SCHEDULED");
            return true;
        } catch (Exception e) {
            Diagnostics.write(context, "TEST_FAILED " + e.getClass().getSimpleName());
            return false;
        }
    }

    private static void cancelAll(Context context, String json) {
        try {
            JSONArray tasks = new JSONArray(json);
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            for (int i = 0; i < tasks.length(); i++) {
                JSONObject task = tasks.optJSONObject(i);
                if (task == null) continue;
                PendingIntent pi = pending(context, task.optString("id"), task.optString("title"), PendingIntent.FLAG_NO_CREATE);
                if (pi != null) { am.cancel(pi); pi.cancel(); }
            }
        } catch (Exception ignored) { }
    }

    private static void scheduleAll(Context context, String json) {
        try {
            JSONArray tasks = new JSONArray(json);
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            long now = System.currentTimeMillis();
            for (int i = 0; i < tasks.length(); i++) {
                JSONObject task = tasks.optJSONObject(i);
                if (task == null || "done".equals(task.optString("status")) || task.optBoolean("alarm_fired")) continue;
                String due = task.optString("due_at", "");
                if (due.isEmpty() || due.equals("null")) continue;
                long when;
                try { when = parseTime(due); }
                catch (Exception ex) { Diagnostics.write(context, "INVALID_TIME " + due); continue; }
                if (when <= now) continue;
                PendingIntent pi = pending(context, task.optString("id"), task.optString("title"), PendingIntent.FLAG_UPDATE_CURRENT);
                if (pi == null) continue;
                try {
                    if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
                    } else {
                        PendingIntent show = PendingIntent.getActivity(context, 31,
                            new Intent(context, MainActivity.class),
                            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                        am.setAlarmClock(new AlarmManager.AlarmClockInfo(when, show), pi);
                    }
                } catch (SecurityException ex) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
                }
            }
        } catch (Exception ignored) { }
    }

    private static long parseTime(String due) {
        try { return Instant.parse(due).toEpochMilli(); }
        catch (DateTimeParseException ignored) { }
        try { return OffsetDateTime.parse(due).toInstant().toEpochMilli(); }
        catch (DateTimeParseException ignored) { }
        return LocalDateTime.parse(due).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
    }

    private static PendingIntent pending(Context context, String id, String title, int flag) {
        if (id == null || id.isEmpty()) return null;
        Intent intent = new Intent(context, AlarmReceiver.class);
        intent.setAction("com.meysam.dailyreminder.RING");
        intent.setData(Uri.parse("reminder://alarm/" + Uri.encode(id)));
        intent.putExtra("title", title);
        return PendingIntent.getBroadcast(context, id.hashCode(), intent, flag | PendingIntent.FLAG_IMMUTABLE);
    }
}
