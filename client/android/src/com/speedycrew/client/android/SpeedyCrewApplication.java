package com.speedycrew.client.android;

import android.app.Application;
import android.content.Context;
import android.util.Log;

public class SpeedyCrewApplication extends Application {
	private static Context context;

	private static String LOGTAG = SpeedyCrewApplication.class.getName();

	public void onCreate() {
		super.onCreate();

		Log.i(LOGTAG, "onCreate");

		SpeedyCrewApplication.context = getApplicationContext();
	}

	public static Context getAppContext() {
		return SpeedyCrewApplication.context;
	}
}