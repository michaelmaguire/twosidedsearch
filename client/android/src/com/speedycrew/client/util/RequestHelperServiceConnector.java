package com.speedycrew.client.util;

import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.os.Messenger;
import android.util.Log;

import com.speedycrew.client.android.connection.ConnectionService;

public class RequestHelperServiceConnector extends ServiceConnector {

	public static final String JSON_KEY_SEARCH_ID = "search_id";

	public RequestHelperServiceConnector(Context context, Class<? extends BaseService> serviceClass) {
		super(context, serviceClass);
	}

	static String LOGTAG = RequestHelperServiceConnector.class.getName();

	public void createSearch(String searchString, boolean isProvider, Handler.Callback handlerCallback) throws Exception {
		try {
			Message createMessage = Message.obtain();
			createMessage.obj = new String("1/create_search");
			createMessage.setData(produceCreateSearchBundle(isProvider, searchString));
			createMessage.what = ConnectionService.MSG_MAKE_REQUEST_WITH_PARAMETERS;
			super.send(createMessage, new Messenger(new Handler(handlerCallback)));
		} catch (Exception e) {
			Log.e(LOGTAG, "send error: " + e);
			throw e;
		}
	}

	public void getSearchResults(String searchId, Handler.Callback handlerCallback) throws Exception {
		try {
			Message fetchResultsMessage = Message.obtain();
			fetchResultsMessage.obj = new String("1/search_results");
			fetchResultsMessage.setData(produceCreateSearchResultsBundle(searchId));
			fetchResultsMessage.what = ConnectionService.MSG_MAKE_REQUEST_WITH_PARAMETERS;
			super.send(fetchResultsMessage, new Messenger(new Handler(handlerCallback)));
		} catch (Exception e) {
			Log.e(LOGTAG, "send error: " + e);
			throw e;
		}
	}

	public void updateProfile(String displayName, String blurbMessage, String contactEmail, Handler.Callback handlerCallback) throws Exception {
		try {
			Message msg = Message.obtain();
			msg.obj = new String("1/update_profile");
			msg.setData(produceProfileUpdateBundle(displayName, blurbMessage, contactEmail));
			msg.what = ConnectionService.MSG_MAKE_REQUEST_WITH_PARAMETERS;
			super.send(msg, new Messenger(new Handler(handlerCallback)));
		} catch (Exception e) {
			Log.e(LOGTAG, "send error: " + e);
			throw e;
		}
	}

	private static Bundle produceProfileUpdateBundle(String real_name, String message, String email) {
		Bundle bundle = new Bundle();

		bundle.putString("real_name", real_name);
		bundle.putString("message", message);
		bundle.putString("email", email);

		return bundle;
	}

	private static Bundle produceCreateSearchBundle(boolean provide, String queryString) {
		Bundle bundle = new Bundle();

		if (provide) {
			bundle.putString("side", "PROVIDE");
		} else {
			bundle.putString("side", "SEEK");
		}
		bundle.putString("query", queryString);

		return bundle;
	}

	private static Bundle produceCreateSearchResultsBundle(String searchId) {
		Bundle bundle = new Bundle();

		bundle.putString("search", searchId);

		return bundle;
	}

}
