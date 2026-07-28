package com.dylan.star_learner;

import android.app.admin.DeviceAdminReceiver;

/**
 * Device-owner admin used only to whitelist Star Learner apps for
 * enterprise lock-task mode (no "App is pinned" SystemUI chrome).
 */
public class AdminReceiver extends DeviceAdminReceiver {
}
