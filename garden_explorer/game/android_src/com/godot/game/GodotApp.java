package com.godot.game;

import org.godotengine.godot.GodotActivity;

import android.content.Intent;
import android.os.Bundle;

import androidx.activity.OnBackPressedCallback;
import androidx.core.splashscreen.SplashScreen;

import java.io.File;

/**
 * Garden Explorer — Back returns to Star Learner; EXTRA_WIPE_SAVE clears progress.
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
		String[] names = {"garden_explorer_save.json"};
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
			File wipe = new File(dir, ".antphone_wipe");
			//noinspection ResultOfMethodCallIgnored
			wipe.createNewFile();
		} catch (Exception ignored) {
		}
	}
}
