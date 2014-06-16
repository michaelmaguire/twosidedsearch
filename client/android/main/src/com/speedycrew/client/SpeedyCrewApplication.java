package com.speedycrew.client;

import android.app.Application;
import android.content.Context;
import android.util.Log;

import com.speedycrew.client.connection.NotificationsReceiver;

public class SpeedyCrewApplication extends Application {
	private static Context context;

	private static String LOGTAG = SpeedyCrewApplication.class.getName();

	public void onCreate() {
		super.onCreate();

		Log.i(LOGTAG, "onCreate");

		SpeedyCrewApplication.context = getApplicationContext();

		NotificationsReceiver.getInstance(this).registerForNotifications(context);
	}

	public static Context getAppContext() {
		return SpeedyCrewApplication.context;
	}
}