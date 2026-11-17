package com.meysam.dailyreminder;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.AlarmManager;
import android.app.AlertDialog;
import android.app.NotificationManager;
import android.media.AudioManager;
import android.os.PowerManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.app.Activity;

public class MainActivity extends Activity {
    private static final String APP_URL = "https://app-f7e51b47.base44.app";
    private WebView web;
    private Button exactButton;
    private long pausedAt;

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        root.setBackgroundColor(0xfff7f9fb);

        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);
        toolbar.setPadding(12, 8, 12, 8);
        toolbar.setOrientation(LinearLayout.HORIZONTAL);
        TextView title = new TextView(this);
        title.setText("یادآور روزانه");
        title.setTextColor(0xff163f55);
        title.setTextSize(15);
        toolbar.addView(title, new LinearLayout.LayoutParams(0, -2, 1));

        exactButton = new Button(this);
        exactButton.setText("مجوز زنگ دقیق");
        exactButton.setTextSize(11);
        exactButton.setOnClickListener(v -> requestExactAlarmAccess());
        toolbar.addView(exactButton);

        Button testButton = new Button(this);
        testButton.setText("تست ۱ دقیقه");
        testButton.setTextSize(11);
        testButton.setOnClickListener(v -> {
            boolean scheduled = AlarmScheduler.scheduleTest(this);
            Toast.makeText(this, scheduled ? "زنگ آزمایشی یک دقیقه دیگر؛ صفحه را قفل کن" :
                "اول مجوز زنگ دقیق را فعال کن", Toast.LENGTH_LONG).show();
            if (!scheduled) requestExactAlarmAccess();
        });
        toolbar.addView(testButton);

        Button soundButton = new Button(this);
        soundButton.setText("تست صدا");
        soundButton.setTextSize(11);
        soundButton.setOnClickListener(v -> {
            Diagnostics.write(this, "MANUAL_SOUND_TEST");
            Intent service = new Intent(this, AlarmService.class);
            service.putExtra("title", "تست فوری صدای زنگ");
            try { startForegroundService(service); }
            catch (Exception ex) {
                Diagnostics.write(this, "MANUAL_ERROR " + ex.getClass().getSimpleName());
                Toast.makeText(this, "خطای اجرای صدا", Toast.LENGTH_LONG).show();
            }
        });
        toolbar.addView(soundButton);

        Button batteryButton = new Button(this);
        batteryButton.setText("باتری");
        batteryButton.setTextSize(11);
        batteryButton.setOnClickListener(v -> {
            try { startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)); }
            catch (Exception ignored) { }
        });
        toolbar.addView(batteryButton);
        root.addView(toolbar, new LinearLayout.LayoutParams(-1, -2));

        Button diagnosticButton = new Button(this);
        diagnosticButton.setText("بررسی وضعیت زنگ و گزارش خطا");
        diagnosticButton.setTextSize(12);
        diagnosticButton.setOnClickListener(v -> showDiagnostics());
        root.addView(diagnosticButton, new LinearLayout.LayoutParams(-1, -2));

        web = new WebView(this);
        web.getSettings().setJavaScriptEnabled(true);
        web.getSettings().setDomStorageEnabled(true);
        web.getSettings().setDatabaseEnabled(true);
        web.getSettings().setMediaPlaybackRequiresUserGesture(false);
        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(web, true);
        web.addJavascriptInterface(new Bridge(), "AndroidReminder");
        web.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if ("app-f7e51b47.base44.app".equalsIgnoreCase(uri.getHost())) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); } catch (Exception ignored) { }
                return true;
            }
        });
        root.addView(web, new LinearLayout.LayoutParams(-1, 0, 1));
        setContentView(root);
        web.loadUrl(APP_URL);

        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 201);
        }
        refreshExactButton();
    }

    private class Bridge {
        @JavascriptInterface public void syncTasks(String json) {
            if (json == null || json.length() > 1000000) return;
            new Handler(Looper.getMainLooper()).post(() -> AlarmScheduler.sync(MainActivity.this, json));
        }
    }

    private void showDiagnostics() {
        AlarmManager am = getSystemService(AlarmManager.class);
        boolean exact = Build.VERSION.SDK_INT < 31 || (am != null && am.canScheduleExactAlarms());
        boolean notify = Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
        PowerManager pm = getSystemService(PowerManager.class);
        boolean battery = pm != null && pm.isIgnoringBatteryOptimizations(getPackageName());
        AudioManager audio = (AudioManager) getSystemService(AUDIO_SERVICE);
        int volume = audio == null ? -1 : audio.getStreamVolume(AudioManager.STREAM_ALARM);
        int maxVolume = audio == null ? -1 : audio.getStreamMaxVolume(AudioManager.STREAM_ALARM);
        String message = "مجوز زنگ دقیق: " + (exact ? "فعال" : "غیرفعال")
            + "\nمجوز اعلان: " + (notify ? "فعال" : "غیرفعال")
            + "\nبدون محدودیت باتری: " + (battery ? "بله" : "خیر")
            + "\nبلندی صدای آلارم: " + volume + "/" + maxVolume
            + "\n\nرویدادهای اخیر:\n" + Diagnostics.read(this);
        new AlertDialog.Builder(this).setTitle("گزارش فنی یادآور")
            .setMessage(message).setPositiveButton("بستن", null).show();
    }

    private void requestExactAlarmAccess() {
        if (Build.VERSION.SDK_INT < 31) return;
        try {
            Intent intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:" + getPackageName()));
            startActivity(intent);
        } catch (Exception ignored) { }
    }

    private void refreshExactButton() {
        if (Build.VERSION.SDK_INT < 31) { exactButton.setVisibility(View.GONE); return; }
        AlarmManager am = getSystemService(AlarmManager.class);
        exactButton.setVisibility(am != null && am.canScheduleExactAlarms() ? View.GONE : View.VISIBLE);
    }

    @Override protected void onResume() {
        super.onResume();
        refreshExactButton();
        AlarmScheduler.rescheduleAll(this);
        if (web != null && pausedAt > 0 && System.currentTimeMillis() - pausedAt > 30000) {
            web.reload();
        }
        pausedAt = 0;
    }

    @Override protected void onPause() {
        pausedAt = System.currentTimeMillis();
        super.onPause();
    }

    @Override public void onBackPressed() {
        if (web != null && web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    @Override protected void onDestroy() {
        if (web != null) web.destroy();
        super.onDestroy();
    }
}
