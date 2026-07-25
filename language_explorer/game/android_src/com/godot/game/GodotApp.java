/**************************************************************************/
/*  GodotApp.java                                                         */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/

package com.godot.game;

import org.godotengine.godot.GodotActivity;

import android.content.Intent;
import android.os.Bundle;

import androidx.activity.OnBackPressedCallback;
import androidx.core.splashscreen.SplashScreen;

import java.io.File;

/**
 * Language Explorer activity: keep the task alive on Back (progress stays warm),
 * and honor a wipe-save intent from the Star Learner kiosk — the same
 * EXTRA_WIPE_SAVE contract Ant/Math Explorer use.
 */
public class GodotApp extends GodotActivity {
	public static final String EXTRA_WIPE_SAVE = "com.dylan.antexplorer.EXTRA_WIPE_SAVE";

	@Override
	public void onCreate(Bundle savedInstanceState) {
		SplashScreen.installSplashScreen(this);
		Intent intent = getIntent();
		if (intent != null && intent.getBooleanExtra(EXTRA_WIPE_SAVE, false)) {
			wipeSaveFiles();
			intent.removeExtra(EXTRA_WIPE_SAVE);
		}
		super.onCreate(savedInstanceState);
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
