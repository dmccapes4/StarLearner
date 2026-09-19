package com.dylan.star_learner;

import android.app.KeyguardManager;
import android.app.Activity;
import android.app.admin.DevicePolicyManager;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.Sensor;
import android.hardware.SensorManager;
import android.hardware.TriggerEvent;
import android.hardware.TriggerEventListener;
import android.os.BatteryManager;
import android.os.Build;
import android.os.PowerManager;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;
import android.view.WindowManager;

/**
 * Battery-aware display policy for the pinned Star Learner appliance.
 * Never shells out to {@code su} — Magisk waitFor on the UI thread ANR'd the launcher.
 */
final class ScreenPowerHelper {

    private static final String TAG = "StarLearnerPower";
    private static final int TIMEOUT_BATTERY_MS = 60_000;
    private static final int TIMEOUT_CHARGING_MS = 10 * 60_000;

    private final Activity activity;
    private final SensorManager sensors;
    private final PowerManager power;
    private Sensor motionSensor;
    private boolean armed;
    private boolean receiverRegistered;
    private long lastWakeMs;

    private final BroadcastReceiver powerReceiver = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            applyPowerPolicy();
        }
    };

    private final TriggerEventListener motionListener = new TriggerEventListener() {
        @Override public void onTrigger(TriggerEvent event) {
            Log.i(TAG, "motion wake");
            wakeScreen();
            armMotionWake();
        }
    };

    private final BroadcastReceiver screenReceiver = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            if (Intent.ACTION_SCREEN_ON.equals(intent.getAction())
                    || Intent.ACTION_USER_PRESENT.equals(intent.getAction())) {
                long now = SystemClock.uptimeMillis();
                if (now - lastWakeMs < 800L) return;
                lastWakeMs = now;
                wakeScreen();
            }
        }
    };

    ScreenPowerHelper(Activity activity) {
        this.activity = activity;
        this.sensors = (SensorManager) activity.getSystemService(Context.SENSOR_SERVICE);
        this.power = (PowerManager) activity.getSystemService(Context.POWER_SERVICE);
        pickMotionSensor();
    }

    void start() {
        enableOemTapWake();
        disableAmbientClockWake();
        disableKeyguardFully();
        IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
        filter.addAction(Intent.ACTION_POWER_CONNECTED);
        filter.addAction(Intent.ACTION_POWER_DISCONNECTED);
        IntentFilter screenFilter = new IntentFilter(Intent.ACTION_SCREEN_ON);
        screenFilter.addAction(Intent.ACTION_USER_PRESENT);
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(powerReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
            activity.registerReceiver(screenReceiver, screenFilter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            activity.registerReceiver(powerReceiver, filter);
            activity.registerReceiver(screenReceiver, screenFilter);
        }
        receiverRegistered = true;
        applyPowerPolicy();
        armMotionWake();
    }

    void stop() {
        if (receiverRegistered) {
            try { activity.unregisterReceiver(powerReceiver); } catch (Exception ignored) {}
            try { activity.unregisterReceiver(screenReceiver); } catch (Exception ignored) {}
            receiverRegistered = false;
        }
        cancelMotionWake();
    }

    void onResume() {
        applyPowerPolicy();
        armMotionWake();
    }

    void applyPowerPolicy() {
        boolean charging = isCharging();
        if (charging) {
            activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
        applyScreenTimeout(charging ? TIMEOUT_CHARGING_MS : TIMEOUT_BATTERY_MS);
        putGlobalInt(Settings.Global.STAY_ON_WHILE_PLUGGED_IN, 0);
    }

    private void applyScreenTimeout(int ms) {
        putSystemInt(Settings.System.SCREEN_OFF_TIMEOUT, ms);
    }

    private void putSystemInt(String key, int value) {
        if (tryDpmSystem(key, value)) return;
        try {
            Settings.System.putInt(activity.getContentResolver(), key, value);
        } catch (Exception e) {
            Log.w(TAG, "system " + key, e);
        }
    }

    private void putGlobalInt(String key, int value) {
        if (tryDpmGlobal(key, value)) return;
        try {
            Settings.Global.putInt(activity.getContentResolver(), key, value);
        } catch (Exception e) {
            // OEM keys (ambient_*) often lack write permission — ignore; ops set via adb.
            Log.w(TAG, "global " + key + " skipped", e);
        }
    }

    private void putSecureInt(String key, int value) {
        if (tryDpmSecure(key, value)) return;
        try {
            Settings.Secure.putInt(activity.getContentResolver(), key, value);
        } catch (Exception e) {
            Log.w(TAG, "secure " + key + " skipped", e);
        }
    }

    private boolean tryDpmSystem(String key, int value) {
        try {
            DevicePolicyManager dpm = dpm();
            if (dpm == null || !dpm.isDeviceOwnerApp(activity.getPackageName())
                    || Build.VERSION.SDK_INT < 28) return false;
            dpm.setSystemSetting(admin(), key, Integer.toString(value));
            return true;
        } catch (Exception e) {
            Log.w(TAG, "dpm system " + key, e);
            return false;
        }
    }

    private boolean tryDpmGlobal(String key, int value) {
        try {
            DevicePolicyManager dpm = dpm();
            if (dpm == null || !dpm.isDeviceOwnerApp(activity.getPackageName())
                    || Build.VERSION.SDK_INT < 28) return false;
            dpm.setGlobalSetting(admin(), key, Integer.toString(value));
            return true;
        } catch (Exception e) {
            Log.w(TAG, "dpm global " + key, e);
            return false;
        }
    }

    private boolean tryDpmSecure(String key, int value) {
        try {
            DevicePolicyManager dpm = dpm();
            if (dpm == null || !dpm.isDeviceOwnerApp(activity.getPackageName())
                    || Build.VERSION.SDK_INT < 28) return false;
            dpm.setSecureSetting(admin(), key, Integer.toString(value));
            return true;
        } catch (Exception e) {
            Log.w(TAG, "dpm secure " + key, e);
            return false;
        }
    }

    private DevicePolicyManager dpm() {
        return (DevicePolicyManager) activity.getSystemService(Context.DEVICE_POLICY_SERVICE);
    }

    private ComponentName admin() {
        return new ComponentName(activity, AdminReceiver.class);
    }

    private boolean isCharging() {
        Intent bat = activity.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (bat == null) return false;
        int plugged = bat.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0);
        return plugged != 0;
    }

    private void pickMotionSensor() {
        if (sensors == null) return;
        motionSensor = sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION, true);
        if (motionSensor == null) {
            motionSensor = sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION);
        }
        if (motionSensor == null && Build.VERSION.SDK_INT >= 23) {
            motionSensor = sensors.getDefaultSensor(25, true);
            if (motionSensor == null) motionSensor = sensors.getDefaultSensor(25);
        }
        if (motionSensor != null) {
            Log.i(TAG, "motion sensor: " + motionSensor.getName()
                    + " wakeup=" + motionSensor.isWakeUpSensor());
        } else {
            Log.w(TAG, "no significant-motion / pick-up sensor — double-tap still available");
        }
    }

    private void armMotionWake() {
        cancelMotionWake();
        if (sensors == null || motionSensor == null) return;
        try {
            armed = sensors.requestTriggerSensor(motionListener, motionSensor);
            if (!armed) Log.w(TAG, "requestTriggerSensor failed");
        } catch (Exception e) {
            Log.w(TAG, "armMotionWake", e);
            armed = false;
        }
    }

    private void cancelMotionWake() {
        if (!armed || sensors == null || motionSensor == null) return;
        try {
            sensors.cancelTriggerSensor(motionListener, motionSensor);
        } catch (Exception ignored) {}
        armed = false;
    }

    private void wakeScreen() {
        try {
            if (Build.VERSION.SDK_INT >= 27) {
                activity.setTurnScreenOn(true);
                activity.setShowWhenLocked(true);
            }
            activity.getWindow().addFlags(
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                            | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD);
            dismissKeyguard();
            if (power != null) {
                @SuppressWarnings("deprecation")
                PowerManager.WakeLock wl = power.newWakeLock(
                        PowerManager.SCREEN_BRIGHT_WAKE_LOCK
                                | PowerManager.ACQUIRE_CAUSES_WAKEUP,
                        "starlearner:motion");
                wl.acquire(3_000L);
                activity.getWindow().getDecorView().postDelayed(() -> {
                    applyPowerPolicy();
                    dismissKeyguard();
                }, 400);
            }
        } catch (Exception e) {
            Log.w(TAG, "wakeScreen", e);
        }
    }

    private void disableKeyguardFully() {
        try {
            DevicePolicyManager dpm = dpm();
            if (dpm != null && dpm.isDeviceOwnerApp(activity.getPackageName())) {
                dpm.setKeyguardDisabled(admin(), true);
                Log.i(TAG, "keyguard disabled (device owner)");
            }
        } catch (Exception e) {
            Log.w(TAG, "setKeyguardDisabled", e);
        }
        dismissKeyguard();
    }

    private void dismissKeyguard() {
        try {
            KeyguardManager km =
                    (KeyguardManager) activity.getSystemService(Context.KEYGUARD_SERVICE);
            if (km == null) return;
            if (Build.VERSION.SDK_INT >= 26) {
                km.requestDismissKeyguard(activity, null);
            }
        } catch (Exception e) {
            Log.w(TAG, "requestDismissKeyguard", e);
        }
    }

    private void enableOemTapWake() {
        putSecureInt("double_tap_to_wake", 1);
        putSecureInt("wake_gesture_enabled", 1);
        putSecureInt("lift_to_wake", 1);
    }

    private void disableAmbientClockWake() {
        putGlobalInt("ambient_enabled", 0);
        putGlobalInt("ambient_touch_to_wake", 0);
        putGlobalInt("ambient_tilt_to_wake", 0);
        putSecureInt("doze_enabled", 0);
        putSecureInt("doze_always_on", 0);
        putSecureInt("doze_pulse_on_double_tap", 0);
        putSecureInt("state_glance_lockscreen", 0);
        putSecureInt("state_space_lockscreen", 0);
        Log.i(TAG, "ambient/peek clock wake disabled");
    }
}
