package com.speedycrew.client;

import android.app.Fragment;
import android.content.AsyncQueryHandler;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemLongClickListener;
import android.widget.CursorTreeAdapter;
import android.widget.ExpandableListView;
import android.widget.ExpandableListView.OnChildClickListener;
import android.widget.ExpandableListView.OnGroupClickListener;
import android.widget.SimpleCursorTreeAdapter;

import com.speedycrew.client.sql.Crew;
import com.speedycrew.client.sql.Match;
import com.speedycrew.client.sql.Message;
import com.speedycrew.client.sql.SyncedContentProvider;

public class MessageListFragment extends Fragment implements
		View.OnClickListener, OnGroupClickListener, OnChildClickListener,
		OnItemLongClickListener {

	protected QueryHandler mQueryHandler;

	protected ExpandableListView mExpandableListView;

	protected MessageListAdapter mMessageListAdapter;

	private static final String LOGTAG = MessageListFragment.class.getName();

	static final String[] CREW_PROJECTION = new String[] { Crew.NAME, Crew.ID,
			Crew._ID };
	static final int[] CREW_VIEWS_FROM_LAYOUT = new int[] { R.id.name, R.id.id };

	static final String[] MESSAGE_PROJECTION = new String[] {
			com.speedycrew.client.sql.Message.SENDER,
			com.speedycrew.client.sql.Message.BODY, Match._ID, };
	static final int[] MESSAGE_VIEWS_FROM_LAYOUT = new int[] { R.id.sender,
			R.id.body };

	static final String SORTED_ORDER = SyncedContentProvider.SQLITE_ROWID
			+ " DESC";

	static final int TOKEN_GROUP = 0;
	static final int TOKEN_CHILD = 1;

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container,
			Bundle savedInstanceState) {
		View rootView = inflater.inflate(R.layout.fragment_message_list,
				container, false);

		mMessageListAdapter = new MessageListAdapter(getActivity());
		mExpandableListView = (ExpandableListView) rootView
				.findViewById(R.id.list);
		mExpandableListView.setAdapter(mMessageListAdapter);
		mExpandableListView.setOnGroupClickListener(this);
		mExpandableListView.setOnChildClickListener(this);
		mExpandableListView.setLongClickable(true);
		mExpandableListView.setOnItemLongClickListener(this);

		mQueryHandler = new QueryHandler(getActivity(), mMessageListAdapter);

		// Query for crew searches.
		mQueryHandler.startQuery(TOKEN_GROUP, null,
				SyncedContentProvider.CREW_URI, CREW_PROJECTION, null, null,
				SORTED_ORDER);

		return rootView;
	}

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
		Log.i(LOGTAG, "MessageListFragment onClick");
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
	public class MessageListAdapter extends SimpleCursorTreeAdapter {

		Context mContext;

		public MessageListAdapter(Context context) {
			// Need to set in projection both the _ID (for Android controls) and
			// ID (retrieved from server).
			// The _ID is needed otherwise you will see errors like Unable to
			// find column 'id'.
			super(context, null, R.layout.message_list_group, CREW_PROJECTION,
					CREW_VIEWS_FROM_LAYOUT, R.layout.message_list_child,
					MESSAGE_PROJECTION, MESSAGE_VIEWS_FROM_LAYOUT);

			mContext = context;
		}

		@Override
		protected Cursor getChildrenCursor(Cursor groupCursor) {
			// Given the group, we return a cursor for all the children within
			// that group

			// Return a cursor that points to this Crew's Messages.
			Uri.Builder builder = SyncedContentProvider.CREW_URI.buildUpon();

			// Must appendPath so that crew id gets encoded as it contains
			// hyphens.
			final int columnIndex = groupCursor.getColumnIndex(Crew.ID);
			final String crewIDString = groupCursor.getString(columnIndex);
			builder.appendPath(crewIDString);

			builder.appendEncodedPath(com.speedycrew.client.sql.Message.TABLE_NAME);
			Uri messageUri = builder.build();

			mQueryHandler.startQuery(MessageListFragment.TOKEN_CHILD,
					groupCursor.getPosition(), messageUri,
					MessageListFragment.MESSAGE_PROJECTION, null, null,
					SORTED_ORDER);

			return null;
		}
	}

	@Override
	public boolean onChildClick(ExpandableListView parent, View v,
			int groupPosition, int childPosition, long id) {

		Cursor cursor = mMessageListAdapter.getChild(groupPosition,
				childPosition);
		String messageId = cursor.getString(cursor.getColumnIndex(Message.ID));

		Log.i(LOGTAG, "onChildClick groupPosition[" + groupPosition
				+ "] childPosition[" + childPosition + "] id[" + id
				+ "] messageId[" + messageId + "]");

		Intent intent = new Intent(getActivity(), MessageActivity.class);
		intent.putExtra(Message.ID, messageId);
		startActivity(intent);

		return true;
	}

	@Override
	public boolean onGroupClick(ExpandableListView parent, View v,
			int groupPosition, long id) {

		Cursor cursor = mMessageListAdapter.getGroup(groupPosition);
		String crewID = cursor.getString(cursor.getColumnIndex(Crew.ID));

		Log.i(LOGTAG, "onGroupClick groupPosition[" + groupPosition + "] id["
				+ id + "] crewID[" + crewID + "]");

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

			Cursor cursor = mMessageListAdapter.getChild(groupPosition,
					childPosition);
			String messageID = cursor.getString(cursor
					.getColumnIndex(Message.ID));

			Log.i(LOGTAG, "onItemLongClick CHILD position[" + position
					+ "] id[" + id + "] groupPosition[" + groupPosition
					+ "] childPosition[" + childPosition + "] messageID["
					+ messageID + "]");

			// handle data

			// return true as we are handling the event.
			return true;
		} else if (ExpandableListView.getPackedPositionType(packedPosition) == ExpandableListView.PACKED_POSITION_TYPE_GROUP) {
			int groupPosition = ExpandableListView
					.getPackedPositionGroup(packedPosition);

			Cursor cursor = mMessageListAdapter.getGroup(groupPosition);
			String crewID = cursor.getString(cursor.getColumnIndex(Crew.ID));

			Log.i(LOGTAG, "onItemLongClick GROUP position[" + position
					+ "] id[" + id + "] groupPosition[" + groupPosition
					+ "] crewID[" + crewID + "]");

			return true;
		} else {
			Log.i(LOGTAG, "onItemLongClick OTHER position[" + position
					+ "] id[" + id + "]");
		}
		return false;
	}
}