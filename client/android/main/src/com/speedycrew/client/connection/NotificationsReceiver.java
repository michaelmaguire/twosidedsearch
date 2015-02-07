package com.speedycrew.client.connection;

import android.app.Activity;
import android.app.IntentService;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager.NameNotFoundException;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.NotificationCompat;
import android.support.v4.content.WakefulBroadcastReceiver;
import android.util.Log;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GooglePlayServicesUtil;
import com.google.android.gms.gcm.GoogleCloudMessaging;
import com.speedycrew.client.MainActivity;
import com.speedycrew.client.R;
import com.speedycrew.client.SpeedyCrewApplication;
import com.speedycrew.client.util.RequestHelper;

public class NotificationsReceiver {
	private static final String LOGTAG = NotificationsReceiver.class.getName();

	private static NotificationsReceiver mNotificationsReceiver;

	public static synchronized NotificationsReceiver getInstance(Context context) {
		if (null == mNotificationsReceiver) {
			mNotificationsReceiver = new NotificationsReceiver(context);
		}
		return mNotificationsReceiver;
	}

	private NotificationsReceiver(Context context) {
	}

	private GoogleCloudMessaging gcm;

	public static final String PROPERTY_REG_ID = "registration_id";
	private static final String PROPERTY_APP_VERSION = "appVersion";
	private final static int PLAY_SERVICES_RESOLUTION_REQUEST = 9000;

	/**
	 * Substitute you own sender ID here. This is the project number you got
	 * from the API Console, as described in "Getting Started."
	 */
	String SENDER_ID = "940995902962";

	String regid;

	public void registerForNotifications(Context context) {
		if (checkPlayServices(context)) {

			gcm = GoogleCloudMessaging.getInstance(context);
			regid = getRegistrationId(context);

			if (regid.isEmpty()) {
				registerInBackground(context);
			}
		} else {
			Log.i(LOGTAG, "No valid Google Play Services APK found.");

		}
	}

	/**
	 * Check the device to make sure it has the Google Play Services APK. If it
	 * doesn't, display a dialog that allows users to download the APK from the
	 * Google Play Store or enable it in the device's system settings.
	 */
	public boolean checkPlayServices(Context context) {
		int resultCode = GooglePlayServicesUtil
				.isGooglePlayServicesAvailable(context);
		if (resultCode != ConnectionResult.SUCCESS) {
			if (GooglePlayServicesUtil.isUserRecoverableError(resultCode)) {
				Log.i(LOGTAG,
						"Play Services need to be installed on this device.");
				// TODO: How to display error dialog with only a context?
				// GooglePlayServicesUtil.getErrorDialog(resultCode, context,
				// PLAY_SERVICES_RESOLUTION_REQUEST).show();
			} else {
				Log.i(LOGTAG, "Play Services not supported on this device.");

				// Non-fatal -- just can't register for push notifications.
				// finish();
			}
			return false;
		}
		return true;
	}

	/**
	 * Registers the application with GCM servers asynchronously.
	 * <p>
	 * Stores the registration ID and app versionCode in the application's
	 * shared preferences.
	 */
	private void registerInBackground(final Context context) {
		new AsyncTask() {
			@Override
			protected Object doInBackground(Object... params) {
				String msg = "";
				try {
					if (gcm == null) {
						gcm = GoogleCloudMessaging.getInstance(context);
					}
					regid = gcm.register(SENDER_ID);
					msg = "Device registered, registration ID=" + regid;

					persistRegistrationId(context, regid);

				} catch (Exception ex) {
					msg = "Error :" + ex.getMessage();
					// If there is an error, don't just keep trying to register.
					// Require the user to click a button again, or perform
					// exponential back-off.
				}
				return msg;
			}

		}.execute(null, null, null);

	}

	private static void persistRegistrationId(Context context, String regid) {
		try {
			// You should send the registration ID to your server over
			// HTTP,
			// so it can use GCM/HTTP or CCS to send messages to your
			// app.
			// The request to your server should be authenticated if
			// your app
			// is using accounts.
			RequestHelper.sendRegistrationIdToBackend(context, regid, null);

			// For this demo: we don't need to send it because the
			// device
			// will send upstream messages to a server that echo back
			// the
			// message using the 'from' address in the message.

			// Persist the regID - no need to register again.
			storeRegistrationId(context, regid);
		} catch (Exception e) {
			Log.e(LOGTAG, "Unable to send registration Id to server", e);
		}
	}

	/**
	 * Gets the current registration ID for application on GCM service.
	 * <p>
	 * If result is empty, the app needs to register.
	 * 
	 * @return registration ID, or empty string if there is no existing
	 *         registration ID.
	 */
	private static String getRegistrationId(Context context) {
		final SharedPreferences prefs = getGCMPreferences(context);
		String registrationId = prefs.getString(PROPERTY_REG_ID, "");
		if (registrationId.isEmpty()) {
			Log.i(LOGTAG, "Registration not found.");
			return "";
		}
		// Check if app was updated; if so, it must clear the registration ID
		// since the existing regID is not guaranteed to work with the new
		// app version.
		int registeredVersion = prefs.getInt(PROPERTY_APP_VERSION,
				Integer.MIN_VALUE);
		int currentVersion = getAppVersion(context);
		if (registeredVersion != currentVersion) {
			Log.i(LOGTAG, "App version changed.");
			return "";
		}
		return registrationId;
	}

	/**
	 * Stores the registration ID and app versionCode in the application's
	 * {@code SharedPreferences}.
	 * 
	 * @param context
	 *            application's context.
	 * @param regId
	 *            registration ID
	 */
	private static void storeRegistrationId(Context context, String regId) {
		final SharedPreferences prefs = getGCMPreferences(context);
		int appVersion = getAppVersion(context);
		Log.i(LOGTAG, "Saving regId on app version " + appVersion);
		SharedPreferences.Editor editor = prefs.edit();
		editor.putString(PROPERTY_REG_ID, regId);
		editor.putInt(PROPERTY_APP_VERSION, appVersion);
		editor.commit();
	}

	/**
	 * @return Application's {@code SharedPreferences}.
	 */
	private static SharedPreferences getGCMPreferences(Context context) {
		// This sample app persists the registration ID in shared preferences,
		// but
		// how you store the regID in your app is up to you.
		return context.getSharedPreferences(MainActivity.class.getSimpleName(),
				Context.MODE_PRIVATE);
	}

	/**
	 * @return Application's version code from the {@code PackageManager}.
	 */
	private static int getAppVersion(Context context) {
		try {
			PackageInfo packageInfo = context.getPackageManager()
					.getPackageInfo(context.getPackageName(), 0);
			return packageInfo.versionCode;
		} catch (NameNotFoundException e) {
			// should never happen
			throw new RuntimeException("Could not get package name: " + e);
		}
	}

	public static class GcmIntentService extends IntentService {
		public static final int NOTIFICATION_ID = 1;
		private NotificationManager mNotificationManager;
		NotificationCompat.Builder mBuilder;

		public GcmIntentService() {
			super("GcmIntentService");
		}

		@Override
		protected void onHandleIntent(Intent intent) {
			try {
				Bundle extras = intent.getExtras();
				Log.i(LOGTAG,
						"GcmIntentService onHandleIntent: " + extras.toString());

				// Check for our workaround to SERVICE_NOT_AVAILABLE from
				// GCM.register:
				// @See
				// http://stackoverflow.com/questions/17618982/gcm-service-not-available-on-android-2-2/17721385#17721385
				String regid = intent.getExtras().getString("registration_id");
				if (regid != null && !regid.equals("")) {
					/*
					 * Do what ever you want with the regId eg. send it to your
					 * server
					 */
					Log.i(LOGTAG, "Received: registration_id[" + regid + "]");

					persistRegistrationId(
							SpeedyCrewApplication.getAppContext(), regid);

				}

				GoogleCloudMessaging gcm = GoogleCloudMessaging
						.getInstance(this);
				// The getMessageType() intent parameter must be the intent you
				// received
				// in your BroadcastReceiver.
				String messageType = gcm.getMessageType(intent);

				if (!extras.isEmpty()) { // has effect of unparcelling Bundle
					/*
					 * Filter messages based on message type. Since it is likely
					 * that GCM will be extended in the future with new message
					 * types, just ignore any message types you're not
					 * interested in, or that you don't recognize.
					 */
					if (GoogleCloudMessaging.MESSAGE_TYPE_MESSAGE
							.equals(messageType)) {
						Log.i(LOGTAG,
								"Received: MESSAGE_TYPE_MESSAGE"
										+ extras.toString());
						RequestHelper.sendSynchronize(
								SpeedyCrewApplication.getAppContext(), null);

						sendNotification("New match available");
					} else if (GoogleCloudMessaging.MESSAGE_TYPE_SEND_ERROR
							.equals(messageType)) {
						Log.i(LOGTAG, "Received: MESSAGE_TYPE_SEND_ERROR");
					} else if (GoogleCloudMessaging.MESSAGE_TYPE_DELETED
							.equals(messageType)) {
						Log.i(LOGTAG, "Received: MESSAGE_TYPE_DELETED");
					}
				}
			} catch (Exception e) {
				Log.e(LOGTAG, "GcmIntentService: Exception", e);
			} finally {
				// Release the wake lock provided by the
				// WakefulBroadcastReceiver.
				GcmBroadcastReceiver.completeWakefulIntent(intent);
			}
		}

		// Put the message into a notification and post it.
		// This is just one simple example of what you might choose to do with
		// a GCM message.
		private void sendNotification(String msg) {
			mNotificationManager = (NotificationManager) this
					.getSystemService(Context.NOTIFICATION_SERVICE);

			PendingIntent contentIntent = PendingIntent.getActivity(this, 0,
					new Intent(this, MainActivity.class), 0);

			NotificationCompat.Builder mBuilder = new NotificationCompat.Builder(
					this)
					.setSmallIcon(R.drawable.notification_icon)
					.setContentTitle("SpeedyCrew Notification")
					.setStyle(
							new NotificationCompat.BigTextStyle().bigText(msg))
					.setContentText(msg);

			mBuilder.setContentIntent(contentIntent);
			mNotificationManager.notify(NOTIFICATION_ID, mBuilder.build());
		}
	}

	public static class GcmBroadcastReceiver extends WakefulBroadcastReceiver {
		@Override
		public void onReceive(Context context, Intent intent) {

			// Explicitly specify that GcmIntentService will handle the intent.
			ComponentName comp = new ComponentName(context.getPackageName(),
					GcmIntentService.class.getName());
			// Start the service, keeping the device awake while it is
			// launching.
			startWakefulService(context, (intent.setComponent(comp)));
			setResultCode(Activity.RESULT_OK);
		}
	}
}
