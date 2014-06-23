package com.speedycrew.client;

import org.json.JSONObject;

import android.app.Fragment;
import android.content.AsyncQueryHandler;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemLongClickListener;
import android.widget.CursorTreeAdapter;
import android.widget.EditText;
import android.widget.ExpandableListView;
import android.widget.ExpandableListView.OnChildClickListener;
import android.widget.ExpandableListView.OnGroupClickListener;
import android.widget.SimpleCursorTreeAdapter;
import android.widget.Toast;

import com.speedycrew.client.connection.ConnectionService;
import com.speedycrew.client.connection.ConnectionService.Key;
import com.speedycrew.client.sql.Match;
import com.speedycrew.client.sql.Search;
import com.speedycrew.client.sql.SyncedContentProvider;
import com.speedycrew.client.util.RequestHelperServiceConnector;

public class SearchFragment extends Fragment implements View.OnClickListener, OnGroupClickListener, OnChildClickListener, OnItemLongClickListener {
	private static final String LOGTAG = SearchFragment.class.getName();

	static final String[] SEARCH_PROJECTION = new String[] { Search._ID, Search.ID, Search.QUERY };

	static final String[] MATCH_PROJECTION = new String[] { Match._ID, Match.USERNAME, Match.FINGERPRINT };

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

	protected ExpandableListView mExpandableListView;

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

								mRequestHelperServiceConnector.sendSynchronize(0, 0, new Handler.Callback() {

									@Override
									public boolean handleMessage(Message msg) {
										Toast.makeText(getActivity(), "Got synchronise results", Toast.LENGTH_SHORT).show();
										return false;
									}
								});

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

		// This is String id from server, not built-in _id.
		final static int SEARCH_ID_COLUMN_INDEX = 1;

		public SearchResultsListAdapter(Context context) {
			// Need to set in projection both the _ID (for Android controls) and
			// ID (retrieved from server).
			// The _ID is needed otherwise you will see errors like Unable to
			// find column 'id'.
			super(context, null, R.layout.search_group, SEARCH_PROJECTION, new int[] { R.id.query, R.id.query, R.id.query }, R.layout.search_result_child, MATCH_PROJECTION,
					new int[] { R.id.fingerprint, R.id.fingerprint, R.id.fingerprint });

			mContext = context;
		}

		@Override
		protected Cursor getChildrenCursor(Cursor groupCursor) {
			// Given the group, we return a cursor for all the children within
			// that
			// group

			// Return a cursor that points to this search's matches
			Uri.Builder builder = SyncedContentProvider.SEARCH_URI.buildUpon();

			// Can't use getColumnIndex() yet because table might not even exist
			// yet, e.g. on first time startup.
			// builder.appendEncodedPath(groupCursor.getString(groupCursor.getColumnIndex(Search.ID)));
			// Must appendPath so that search id gets encoded as it contains
			// hyphens.
			builder.appendPath(groupCursor.getString(SEARCH_ID_COLUMN_INDEX));

			builder.appendEncodedPath(Match.TABLE_NAME);
			Uri matchUri = builder.build();

			mQueryHandler.startQuery(SearchFragment.TOKEN_CHILD, groupCursor.getPosition(), matchUri, SearchFragment.MATCH_PROJECTION, null, null, null);

			return null;
		}
	}

	@Override
	public boolean onChildClick(ExpandableListView parent, View v, int groupPosition, int childPosition, long id) {
		Log.i(LOGTAG, "onChildClick groupPosition[" + groupPosition + "] childPosition[" + childPosition + "] id[" + id + "]");

		return false;
	}

	@Override
	public boolean onGroupClick(ExpandableListView parent, View v, int groupPosition, long id) {
		Log.i(LOGTAG, "onGroupClick groupPosition[" + groupPosition + "] id[" + id + "]");

		return false;
	}

	@Override
	public boolean onItemLongClick(AdapterView<?> parent, View view, int position, long id) {
		Log.i(LOGTAG, "onItemLongClick position[" + position + "] id[" + id + "]");

		long packedPosition = mExpandableListView.getExpandableListPosition(position);
		if (ExpandableListView.getPackedPositionType(packedPosition) == ExpandableListView.PACKED_POSITION_TYPE_CHILD) {
			// get item ID's
			int groupPosition = ExpandableListView.getPackedPositionGroup(packedPosition);
			int childPosition = ExpandableListView.getPackedPositionChild(packedPosition);
			Log.i(LOGTAG, "onItemLongClick CHILD position[" + position + "] id[" + id + "] groupPosition[" + groupPosition + "] childPosition[" + childPosition + "]");

			// handle data

			// return true as we are handling the event.
			return true;
		} else if (ExpandableListView.getPackedPositionType(packedPosition) == ExpandableListView.PACKED_POSITION_TYPE_GROUP) {
			int groupPosition = ExpandableListView.getPackedPositionGroup(packedPosition);

			Log.i(LOGTAG, "onItemLongClick GROUP position[" + position + "] id[" + id + "] groupPosition[" + groupPosition + "]");

			return true;
		}
		return false;
	}
}