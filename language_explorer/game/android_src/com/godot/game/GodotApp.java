/**************************************************************************/
/*  GodotApp.java                                                         */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/

package com.godot.game;

import org.godotengine.godot.GodotActivity;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;

import androidx.activity.OnBackPressedCallback;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.splashscreen.SplashScreen;

import java.io.File;

/**
 * Language Explorer activity: keep the task alive on Back (progress stays warm),
 * honor wipe-save from the Star Learner kiosk, and claim RECORD_AUDIO up front
 * so the first Voice mic tap is not eaten by the permission dialog.
 */
public class GodotApp extends GodotActivity {
	public static final String EXTRA_WIPE_SAVE = "com.dylan.star_learner.EXTRA_WIPE_SAVE";
	private static final int REQ_RECORD_AUDIO = 4401;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		SplashScreen.installSplashScreen(this);
		Intent intent = getIntent();
		if (intent != null && intent.getBooleanExtra(EXTRA_WIPE_SAVE, false)) {
			wipeSaveFiles();
			intent.removeExtra(EXTRA_WIPE_SAVE);
		}
		super.onCreate(savedInstanceState);
		requestMicUpFront();
		getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
			@Override
			public void handleOnBackPressed() {
				moveTaskToBack(true);
			}
		});
	}

	@Override
	public void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		setIntent(intent);
		if (intent != null && intent.getBooleanExtra(EXTRA_WIPE_SAVE, false)) {
			wipeSaveFiles();
			intent.removeExtra(EXTRA_WIPE_SAVE);
		}
	}

	@Override
	protected void onResume() {
		super.onResume();
		// Selfish: if the user bounced through another title, re-assert permission.
		requestMicUpFront();
	}

	private void requestMicUpFront() {
		if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
				== PackageManager.PERMISSION_GRANTED) {
			return;
		}
		ActivityCompat.requestPermissions(
				this,
				new String[] {Manifest.permission.RECORD_AUDIO},
				REQ_RECORD_AUDIO);
	}

	private void wipeSaveFiles() {
		File dir = getFilesDir();
		if (dir == null) {
			return;
		}
		String[] names = {"language_explorer_save.json"};
		for (String name : names) {
			File f = new File(dir, name);
			if (f.isFile()) {
				//noinspection ResultOfMethodCallIgnored
				f.delete();
			}
		}
		File[] children = dir.listFiles();
		if (children != null) {
			for (File child : children) {
				if (child != null && child.isFile() && child.getName().endsWith("_save.json")) {
					//noinspection ResultOfMethodCallIgnored
					child.delete();
				}
			}
		}
		try {
			new File(dir, ".antphone_wipe").createNewFile();
		} catch (Exception ignored) {
		}
	}
}
