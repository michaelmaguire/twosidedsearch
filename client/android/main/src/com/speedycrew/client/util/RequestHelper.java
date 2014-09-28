package com.speedycrew.client.util;

import java.util.UUID;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Message;
import android.os.ResultReceiver;
import android.util.Log;

import com.speedycrew.client.connection.ConnectionService;

public abstract class RequestHelper {

	static String LOGTAG = RequestHelper.class.getName();

	public static void createSearch(Context context, String searchString,
			boolean isProvider, ResultReceiver resultReceiver) throws Exception {
		try {
			Uri uri = Uri.parse("1/create_search");
			Bundle bundle = produceCreateSearchBundle(isProvider, searchString);
			bundle.putParcelable(ConnectionService.BUNDLE_KEY_RESULT_RECEIVER,
					resultReceiver);
			Intent intent = new Intent(
					ConnectionService.ACTION_MAKE_LOCATION_ENRICHED_REQUEST_WITH_PARAMETERS,
					uri, context, ConnectionService.class);
			intent.putExtras(bundle);
			context.startService(intent);
		} catch (Exception e) {
			Log.e(LOGTAG, "createSearch send error: " + e);
			throw e;
		}
	}

	public static void getSearchResults(Context context, String searchId,
			ResultReceiver resultReceiver) throws Exception {
		try {
			Uri uri = Uri.parse("1/search_results");
			Bundle bundle = produceCreateSearchResultsBundle(searchId);
			bundle.putParcelable(ConnectionService.BUNDLE_KEY_RESULT_RECEIVER,
					resultReceiver);
			Intent intent = new Intent(
					ConnectionService.ACTION_MAKE_SIMPLE_REQUEST_WITH_PARAMETERS,
					uri, context, ConnectionService.class);
			intent.putExtras(bundle);
			context.startService(intent);
		} catch (Exception e) {
			Log.e(LOGTAG, "getSearchResults send error: " + e);
			throw e;
		}
	}

	public static void sendMessage(Context context, String crewId,
			String messageId, String bodyTextString,
			ResultReceiver resultReceiver) throws Exception {
		try {
			if (messageId == null) {
				UUID uuid = UUID.randomUUID();
				messageId = uuid.toString();
				Log.i(LOGTAG,
						"sendMessage generating randomUUID for messageId["
								+ messageId + "]");
			}

			Uri uri = Uri.parse("1/send_message");
			Bundle bundle = produceSendMessageBundle(crewId, messageId,
					bodyTextString);
			bundle.putParcelable(ConnectionService.BUNDLE_KEY_RESULT_RECEIVER,
					resultReceiver);
			Intent intent = new Intent(
					ConnectionService.ACTION_MAKE_SIMPLE_REQUEST_WITH_PARAMETERS,
					uri, context, ConnectionService.class);
			intent.putExtras(bundle);
			context.startService(intent);
		} catch (Exception e) {
			Log.e(LOGTAG, "createSearch send error: " + e);
			throw e;
		}
	}

	public static void updateProfile(Context context, String username,
			String displayName, String blurbMessage, String contactEmail,
			ResultReceiver resultReceiver) throws Exception {
		try {
			Uri uri = Uri.parse("1/update_profile");
			Bundle bundle = produceProfileUpdateBundle(username, displayName,
					blurbMessage, contactEmail);
			bundle.putParcelable(ConnectionService.BUNDLE_KEY_RESULT_RECEIVER,
					resultReceiver);
			Intent intent = new Intent(
					ConnectionService.ACTION_MAKE_SIMPLE_REQUEST_WITH_PARAMETERS,
					uri, context, ConnectionService.class);
			intent.putExtras(bundle);
			context.startService(intent);
		} catch (Exception e) {
			Log.e(LOGTAG, "updateProfile send error: " + e);
			throw e;
		}
	}

	public static void sendRegistrationIdToBackend(Context context,
			String regid, ResultReceiver resultReceiver) throws Exception {
		try {
			Uri uri = Uri.parse("1/set_notification");
			Bundle bundle = new Bundle();
			bundle.putString(
					ConnectionService.Key.PARAMETER_NAME_GOOGLE_REGISTRATION_ID,
					regid);
			bundle.putParcelable(ConnectionService.BUNDLE_KEY_RESULT_RECEIVER,
					resultReceiver);
			Intent intent = new Intent(
					ConnectionService.ACTION_MAKE_SIMPLE_REQUEST_WITH_PARAMETERS,
					uri, context, ConnectionService.class);
			intent.putExtras(bundle);
			context.startService(intent);
		} catch (Exception e) {
			Log.e(LOGTAG, "sendRegistrationIdToBackend send error: " + e);
			throw e;
		}
	}

	public static void sendSynchronize(Context context, long timeline,
			long sequence, ResultReceiver resultReceiver) throws Exception {
		try {
			Message msg = Message.obtain();
			// Note NZ 's' instead 'z'.
			Uri uri = Uri.parse("1/synchronise");
			Bundle bundle = new Bundle();
			bundle.putString(ConnectionService.Key.TIMELINE,
					Long.toString(timeline));
			bundle.putString(ConnectionService.Key.SEQUENCE,
					Long.toString(sequence));
			bundle.putParcelable(ConnectionService.BUNDLE_KEY_RESULT_RECEIVER,
					resultReceiver);
			Intent intent = new Intent(
					ConnectionService.ACTION_MAKE_SIMPLE_REQUEST_WITH_PARAMETERS,
					uri, context, ConnectionService.class);
			intent.putExtras(bundle);
			context.startService(intent);
		} catch (Exception e) {
			Log.e(LOGTAG, "sendSynchronize send error: " + e);
			throw e;
		}
	}

	private static Bundle produceProfileUpdateBundle(String username,
			String real_name, String message, String email) {
		Bundle bundle = new Bundle();

		bundle.putString(ConnectionService.Key.USERNAME, username);
		bundle.putString(ConnectionService.Key.REAL_NAME, real_name);
		bundle.putString(ConnectionService.Key.MESSAGE, message);
		bundle.putString(ConnectionService.Key.EMAIL, email);

		return bundle;
	}

	private static Bundle produceCreateSearchBundle(boolean provide,
			String queryString) {
		Bundle bundle = new Bundle();

		if (provide) {
			bundle.putString(ConnectionService.Key.SIDE,
					ConnectionService.Key.VALUE_SIDE_PROVIDE);
		} else {
			bundle.putString(ConnectionService.Key.SIDE,
					ConnectionService.Key.VALUE_SIDE_SEEK);
		}
		bundle.putString(ConnectionService.Key.QUERY, queryString);

		return bundle;
	}

	private static Bundle produceCreateSearchResultsBundle(String searchId) {
		Bundle bundle = new Bundle();

		bundle.putString(ConnectionService.Key.SEARCH, searchId);

		return bundle;
	}

	private static Bundle produceSendMessageBundle(String crewId,
			String messageId, String bodyText) {
		Bundle bundle = new Bundle();

		bundle.putString(com.speedycrew.client.sql.Message.CREW, crewId);
		bundle.putString(com.speedycrew.client.sql.Message.ID, messageId);
		bundle.putString(com.speedycrew.client.sql.Message.BODY, bodyText);

		return bundle;
	}

}
