package com.speedycrew.client;

import org.json.JSONObject;

import android.app.Fragment;
import android.content.AsyncQueryHandler;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.ResultReceiver;
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
import com.speedycrew.client.util.RequestHelper;

public class SearchFragment extends Fragment implements View.OnClickListener,
		OnGroupClickListener, OnChildClickListener, OnItemLongClickListener {
	private static final String LOGTAG = SearchFragment.class.getName();

	static final String[] SEARCH_PROJECTION = new String[] { Search.QUERY,
			Search.ID, Search._ID };
	static final int[] SEARCH_VIEWS_FROM_LAYOUT = new int[] { R.id.query };

	static final String[] MATCH_PROJECTION = new String[] { Match.QUERY,
			Match.DISTANCE, Match.USERNAME, Match.SEARCH, Match.OTHER_SEARCH,
			Match._ID, };
	static final int[] MATCH_VIEWS_FROM_LAYOUT = new int[] { R.id.query,
			R.id.distance };

	static final String SORTED_ORDER = SyncedContentProvider.SQLITE_ROWID
			+ " DESC";

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

		// Our adapter and queryHandler is set up in our subclass'
		// onCreateView() method.

	}

	@Override
	public void onClick(View view) {
		Log.i(LOGTAG, "SearchFragment onClick");
		EditText searchText = (EditText) ((View) view.getParent())
				.findViewById(R.id.queryString);
		final String queryString = searchText.getText().toString();
		Log.i(LOGTAG, "SearchFragment queryString[" + queryString + ']');

		try {
			RequestHelper.createSearch(getActivity(), queryString,
					this instanceof HiringFragment, new ResultReceiver(
							new Handler()) {

						@Override
						public void onReceiveResult(int resultCode,
								Bundle resultData) {
							Log.i(LOGTAG,
									"onReceiveResult from createSearch resultCode["
											+ resultCode + "] resultData["
											+ resultData + "]");

							try {
								String jsonString = resultData
										.getString(ConnectionService.BUNDLE_KEY_JSON_RESPONSE);
								JSONObject responseJson = new JSONObject(
										jsonString);
								String status = responseJson
										.getString(Key.STATUS);
								if (!"OK".equalsIgnoreCase(status)) {
									String errorMessage = responseJson
											.getString(ConnectionService.Key.MESSAGE);

									Toast.makeText(getActivity(), errorMessage,
											Toast.LENGTH_SHORT).show();

								} else {

									// We no longer do this, since we now get
									// back
									// synchronize results in every response for
									// which
									// we send timeline and sequence.
									// RequestHelper.sendSynchronize(getActivity(),
									// 0,
									// 0, new ResultReceiver(new Handler()) {
									//
									// @Override
									// public void onReceiveResult(int
									// resultCode,
									// Bundle resultData) {
									// Log.i(LOGTAG,
									// "onReceiveResult from synchronize resultCode["
									// +
									// resultCode + "] resultData[" + resultData
									// + "]");
									// Toast.makeText(getActivity(),
									// "Got synchronise results",
									// Toast.LENGTH_SHORT).show();
									// }
									// });
									//
								}
							} catch (Exception e) {
								Log.e(LOGTAG, "onClick get results error: " + e);
							}
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

		public SearchResultsListAdapter(Context context) {
			// Need to set in projection both the _ID (for Android controls) and
			// ID (retrieved from server).
			// The _ID is needed otherwise you will see errors like Unable to
			// find column 'id'.
			super(context, null, R.layout.search_group, SEARCH_PROJECTION,
					SEARCH_VIEWS_FROM_LAYOUT, R.layout.search_result_child,
					MATCH_PROJECTION, MATCH_VIEWS_FROM_LAYOUT);

			mContext = context;
		}

		@Override
		protected Cursor getChildrenCursor(Cursor groupCursor) {
			// Given the group, we return a cursor for all the children within
			// that group

			// Return a cursor that points to this search's matches
			Uri.Builder builder = SyncedContentProvider.SEARCH_URI.buildUpon();

			// Must appendPath so that search id gets encoded as it contains
			// hyphens.
			final int columnIndex = groupCursor.getColumnIndex(Search.ID);
			final String searchIDString = groupCursor.getString(columnIndex);
			builder.appendPath(searchIDString);

			builder.appendEncodedPath(Match.TABLE_NAME);
			Uri matchUri = builder.build();

			mQueryHandler.startQuery(SearchFragment.TOKEN_CHILD,
					groupCursor.getPosition(), matchUri,
					SearchFragment.MATCH_PROJECTION, null, null, SORTED_ORDER);

			return null;
		}
	}

	@Override
	public boolean onChildClick(ExpandableListView parent, View v,
			int groupPosition, int childPosition, long id) {

		Cursor cursor = mSearchResultsListAdapter.getChild(groupPosition,
				childPosition);
		String search = cursor.getString(cursor.getColumnIndex(Match.SEARCH));
		String other_search = cursor.getString(cursor
				.getColumnIndex(Match.OTHER_SEARCH));

		Log.i(LOGTAG, "onChildClick groupPosition[" + groupPosition
				+ "] childPosition[" + childPosition + "] id[" + id
				+ "] search[" + search + "] other_search[" + other_search + "]");

		Intent intent = new Intent(getActivity(), MatchActivity.class);
		intent.putExtra(Match.SEARCH, search);
		intent.putExtra(Match.OTHER_SEARCH, other_search);
		startActivity(intent);

		return true;
	}

	@Override
	public boolean onGroupClick(ExpandableListView parent, View v,
			int groupPosition, long id) {

		Cursor cursor = mSearchResultsListAdapter.getGroup(groupPosition);
		String searchID = cursor.getString(cursor.getColumnIndex(Search.ID));

		Log.i(LOGTAG, "onGroupClick groupPosition[" + groupPosition + "] id["
				+ id + "] searchID[" + searchID + "]");

		return false;
	}

	@Override
	public boolean onItemLongClick(AdapterView<?> parent, View view,
			int position, long id) {

		long packedPosition = mExpandableListView
				.getExpandableListPosition(position);
		if (ExpandableListView.getPackedPositionType(packedPosition) == ExpandableListView.PACKED_POSITION_TYPE_CHILD) {
			// get item ID's
			int groupPosition = ExpandableListView
					.getPackedPositionGroup(packedPosition);
			int childPosition = ExpandableListView
					.getPackedPositionChild(packedPosition);

			Cursor cursor = mSearchResultsListAdapter.getChild(groupPosition,
					childPosition);
			String matchID = cursor.getString(cursor
					.getColumnIndex(Match.SEARCH))
					+ '|'
					+ cursor.getString(cursor
							.getColumnIndex(Match.OTHER_SEARCH));

			Log.i(LOGTAG, "onItemLongClick CHILD position[" + position
					+ "] id[" + id + "] groupPosition[" + groupPosition
					+ "] childPosition[" + childPosition + "] matchID["
					+ matchID + "]");

			// handle data

			// return true as we are handling the event.
			return true;
		} else if (ExpandableListView.getPackedPositionType(packedPosition) == ExpandableListView.PACKED_POSITION_TYPE_GROUP) {
			int groupPosition = ExpandableListView
					.getPackedPositionGroup(packedPosition);

			Cursor cursor = mSearchResultsListAdapter.getGroup(groupPosition);
			String searchID = cursor
					.getString(cursor.getColumnIndex(Search.ID));

			Log.i(LOGTAG, "onItemLongClick GROUP position[" + position
					+ "] id[" + id + "] groupPosition[" + groupPosition
					+ "] searchID[" + searchID + "]");

			return true;
		} else {
			Log.i(LOGTAG, "onItemLongClick OTHER position[" + position
					+ "] id[" + id + "]");
		}
		return false;
	}
}