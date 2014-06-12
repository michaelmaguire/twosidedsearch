package com.speedycrew.client;

import org.json.JSONObject;

import android.app.Fragment;
import android.content.AsyncQueryHandler;
import android.content.Context;
import android.database.Cursor;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.provider.ContactsContract.CommonDataKinds.Phone;
import android.util.Log;
import android.view.View;
import android.widget.CursorTreeAdapter;
import android.widget.EditText;
import android.widget.Toast;

import com.speedycrew.client.connection.ConnectionService;
import com.speedycrew.client.connection.ConnectionService.Key;
import com.speedycrew.client.sql.SyncedContentProvider;
import com.speedycrew.client.util.RequestHelperServiceConnector;

public class SearchFragment extends Fragment implements View.OnClickListener {
	private static final String LOGTAG = SearchFragment.class.getName();

	private static final String[] SEARCH_PROJECTION = new String[] { SyncedContentProvider._ID, SyncedContentProvider.DISPLAY_NAME };
	private static final int GROUP_ID_COLUMN_INDEX = 0;

	private static final String[] MATCH_PROJECTION = new String[] { Phone._ID, Phone.NUMBER };

	private static final int TOKEN_GROUP = 0;
	private static final int TOKEN_CHILD = 1;

	static final class QueryHandler extends AsyncQueryHandler {
		private CursorTreeAdapter mAdapter;

		public QueryHandler(Context context, CursorTreeAdapter adapter) {
			super(context.getContentResolver());
			this.mAdapter = adapter;
		}

		@Override
		protected void onQueryComplete(int token, Object cookie, Cursor cursor) {
			switch (token) {
			case TOKEN_GROUP:
				mAdapter.setGroupCursor(cursor);
				break;

			case TOKEN_CHILD:
				int groupPosition = (Integer) cookie;
				mAdapter.setChildrenCursor(groupPosition, cursor);
				break;
			}
		}
	}

	private RequestHelperServiceConnector mRequestHelperServiceConnector;

	protected QueryHandler mQueryHandler;

	protected SearchResultsListAdapter mSearchResultsListAdapter;

	@Override
	public void onCreate(Bundle saved) {
		super.onCreate(saved);
		if (null != saved) {
			// Restore state here
		}
		Log.i(LOGTAG, "onCreate");

		mRequestHelperServiceConnector = new RequestHelperServiceConnector(getActivity(), ConnectionService.class);

		mRequestHelperServiceConnector.start();

	}

	@Override
	public void onClick(View view) {
		Log.i(LOGTAG, "SearchFragment onClick");
		EditText searchText = (EditText) ((View) view.getParent()).findViewById(R.id.queryString);
		final String queryString = searchText.getText().toString();
		Log.i(LOGTAG, "SearchFragment queryString[" + queryString + ']');

		try {
			mRequestHelperServiceConnector.createSearch(queryString, this instanceof HiringFragment, new Handler.Callback() {
				@Override
				public boolean handleMessage(Message responseMessage) {
					switch (responseMessage.what) {
					case ConnectionService.MSG_JSON_RESPONSE:
						try {
							final String responseString = responseMessage.obj.toString();
							Log.i(LOGTAG, "handleMessage create search MSG_JSON_RESPONSE: " + responseString);

							JSONObject responseJson = new JSONObject(responseString);
							String status = responseJson.getString(Key.STATUS);
							if (!"OK".equalsIgnoreCase(status)) {
								String errorMessage = responseJson.getString(ConnectionService.Key.MESSAGE);

								Toast.makeText(getActivity(), errorMessage, Toast.LENGTH_SHORT).show();

							} else {

								// TODO: Refresh expandable list from database.

							}
						} catch (Exception e) {
							Log.e(LOGTAG, "onClick get results error: " + e);
						}

						return true;
						// break;
					}
					return false;
				}
			});
		} catch (Exception e) {
			Log.e(LOGTAG, "onClick error: " + e);
		}
	}

}