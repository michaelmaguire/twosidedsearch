package com.speedycrew.client;

import org.json.JSONObject;

import android.app.Fragment;
import android.content.AsyncQueryHandler;
import android.content.ContentUris;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.provider.ContactsContract.CommonDataKinds.Phone;
import android.util.Log;
import android.view.View;
import android.widget.CursorTreeAdapter;
import android.widget.EditText;
import android.widget.SimpleCursorTreeAdapter;
import android.widget.Toast;

import com.speedycrew.client.connection.ConnectionService;
import com.speedycrew.client.connection.ConnectionService.Key;
import com.speedycrew.client.sql.Match;
import com.speedycrew.client.sql.Search;
import com.speedycrew.client.sql.SyncedContentProvider;
import com.speedycrew.client.util.RequestHelperServiceConnector;

public class SearchFragment extends Fragment implements View.OnClickListener {
	private static final String LOGTAG = SearchFragment.class.getName();

	static final String[] SEARCH_PROJECTION = new String[] { Search._ID, Search.QUERY_STRING };

	static final String[] MATCH_PROJECTION = new String[] { Match._ID, Match.OWNER };

	static final int TOKEN_GROUP = 0;
	static final int TOKEN_CHILD = 1;

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

		// Our adapter and queryHandler is set up in our subclass'
		// onCreateView() method.

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

	/**
	 * Following examples at
	 * http://www.vogella.com/tutorials/AndroidSQLite/article.html and
	 * http://www
	 * .java2s.com/Code/Android/UI/DemonstratesexpandablelistsbackedbyCursors
	 * .htm
	 * 
	 * @author michael
	 * 
	 */
	public class SearchResultsListAdapter extends SimpleCursorTreeAdapter {

		Context mContext;
		private static final int GROUP_ID_COLUMN_INDEX = 0;

		public SearchResultsListAdapter(Context context) {
			super(context, null, android.R.layout.simple_expandable_list_item_1, new String[] { Search.QUERY_STRING }, new int[] { android.R.id.text1 },
					android.R.layout.simple_expandable_list_item_1, new String[] { Match.OWNER }, new int[] { android.R.id.text1 });

			mContext = context;
		}

		@Override
		protected Cursor getChildrenCursor(Cursor groupCursor) {
			// Given the group, we return a cursor for all the children within
			// that
			// group

			// Return a cursor that points to this search's matches
			Uri.Builder builder = SyncedContentProvider.CONTENT_URI.buildUpon();
			ContentUris.appendId(builder, groupCursor.getLong(GROUP_ID_COLUMN_INDEX));
			builder.appendEncodedPath(Match.TABLE_NAME);
			Uri matchUri = builder.build();

			mQueryHandler.startQuery(SearchFragment.TOKEN_CHILD, groupCursor.getPosition(), matchUri, SearchFragment.MATCH_PROJECTION, Phone.MIMETYPE + "=?",
					new String[] { Phone.CONTENT_ITEM_TYPE }, null);

			return null;
		}

	}
}