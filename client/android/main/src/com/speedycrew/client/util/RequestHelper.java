package com.speedycrew.client.util;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Message;
import android.os.ResultReceiver;
import android.util.Log;

import com.speedycrew.client.connection.ConnectionService;
import com.speedycrew.client.sql.Control;
import com.speedycrew.client.sql.Crew;
import com.speedycrew.client.sql.Profile;
import com.speedycrew.client.sql.Search;

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

	public static void getSearchResults(Context context, Search search,
			ResultReceiver resultReceiver) throws Exception {
		try {
			Uri uri = Uri.parse("1/search_results");
			Bundle bundle = produceCreateSearchResultsBundle(search);
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

	/**
	 * One of crew or fingerprint may be null, depending on whether we're
	 * replying to a user fingerprint specified in a match, or whether we're
	 * adding to an existing crewId chat.
	 * 
	 * messageId may be null, in which case a new UUID will be randomly
	 * generated.
	 */
	public static void sendMessage(Context context, Crew crew,
			Profile fingerprint, com.speedycrew.client.sql.Message message,
			String bodyTextString, ResultReceiver resultReceiver)
			throws Exception {
		try {
			if (message == null) {
				message = new com.speedycrew.client.sql.Message();
			}

			Uri uri = Uri.parse("1/send_message");
			Bundle bundle = produceSendMessageBundle(crew, message,
					fingerprint, bodyTextString);
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

	public static void sendSynchronize(Context context,
			ResultReceiver resultReceiver) throws Exception {
		sendSynchronize(context, null, null, resultReceiver);
	}

	/**
	 * This method is to be used only when you want explicit control over
	 * setting timeline and sequence. Use the other sendSynchronize() method
	 * without itmeline and sequence if you want the default behaviour which
	 * queries our 'control' table for the correct values.
	 * 
	 */
	public static void sendSynchronize(Context context, Long timeline,
			Long sequence, ResultReceiver resultReceiver) throws Exception {
		try {
			Message msg = Message.obtain();
			// Note NZ 's' instead 'z'.
			Uri uri = Uri.parse("1/synchronise");
			Bundle bundle = new Bundle();
			if (timeline != null) {
				bundle.putLong(Control.TIMELINE, timeline);
			}
			if (sequence != null) {
				bundle.putLong(Control.SEQUENCE, sequence);
			}
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
			String real_name, String blurbMessage, String email) {
		Bundle bundle = new Bundle();

		bundle.putString(ConnectionService.Key.USERNAME, username);
		bundle.putString(ConnectionService.Key.REAL_NAME, real_name);
		bundle.putString(ConnectionService.Key.MESSAGE, blurbMessage);
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

	private static Bundle produceCreateSearchResultsBundle(Search search) {
		Bundle bundle = new Bundle();

		search.addToBundle(bundle);

		return bundle;
	}

	/**
	 * One of crewId or fingerprint may be null, depending on whether we're
	 * replying to a user fingerprint specified in a match, or whether we're
	 * adding to an existing crewId chat.
	 * 
	 * messageId may be null, in which case a new UUID will be randomly
	 * generated.
	 */
	private static Bundle produceSendMessageBundle(Crew crew,
			com.speedycrew.client.sql.Message message, Profile fingerprint,
			String bodyText) {
		Bundle bundle = new Bundle();

		if (crew != null) {
			crew.addToBundle(bundle);
		}
		if (fingerprint != null) {
			fingerprint.addToBundle(bundle);
		}
		message.addToBundle(bundle);
		bundle.putString(com.speedycrew.client.sql.Message.BODY, bodyText);

		return bundle;
	}

}
