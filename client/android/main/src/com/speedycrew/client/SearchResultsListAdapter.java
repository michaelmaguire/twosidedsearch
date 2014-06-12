package com.speedycrew.client;

import com.speedycrew.client.sql.SyncedContentProvider;

import android.content.ContentUris;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.ContactsContract.CommonDataKinds.Phone;
import android.widget.SimpleCursorTreeAdapter;

// TODO: Change to be a subclass of
// http://developer.android.com/reference/android/widget/SimpleCursorTreeAdapter.html
// and then follow example in
// http://www.vogella.com/tutorials/AndroidSQLite/article.html to
// hook this in with a database.
public class SearchResultsListAdapter extends SimpleCursorTreeAdapter {

	Context mContext;

	public SearchResultsListAdapter(Context context) {
		super(context, cursor, android.R.layout.simple_expandable_list_item_1, new String[] { SyncedContentProvider.SEARCH_COLUMN_QUERY }, groupTo, android.R.layout.simple_expandable_list_item_1, new String {SyncedContentProvider.MATCH_COLUMN_OWNER}, childTo);

		mContext = context;
	}

	/*
	 * @Override public View getGroupView(int groupPosition, boolean isExpanded,
	 * View convertView, ViewGroup parent) { String searchName =
	 * getGroup(groupPosition).toString(); if (convertView == null) {
	 * LayoutInflater inflater = (LayoutInflater)
	 * getActivity().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
	 * convertView = inflater.inflate(R.layout.search_group, null); } TextView
	 * item = (TextView) convertView.findViewById(R.id.queryString);
	 * item.setTypeface(null, Typeface.BOLD); item.setText(searchName); return
	 * convertView; }
	 * 
	 * @Override public View getChildView(final int groupPosition, final int
	 * childPosition, boolean isLastChild, View convertView, ViewGroup parent) {
	 * final String searchResult = getChild(groupPosition,
	 * childPosition).toString(); LayoutInflater inflater =
	 * getActivity().getLayoutInflater();
	 * 
	 * if (convertView == null) { convertView =
	 * inflater.inflate(R.layout.search_result_child, null); }
	 * 
	 * TextView item = (TextView) convertView.findViewById(R.id.result);
	 * 
	 * convertView.setOnClickListener(new OnClickListener() {
	 * 
	 * public void onClick(View v) { Log.e(LOGTAG, "onClick for search result: "
	 * + searchResult);
	 * 
	 * } });
	 * 
	 * item.setText(searchResult); return convertView; }
	 */

	@Override
	protected Cursor getChildrenCursor(Cursor groupCursor) {
		// Given the group, we return a cursor for all the children within that
		// group

		// Return a cursor that points to this contact's phone numbers
		Uri.Builder builder = Contacts.CONTENT_URI.buildUpon();
		ContentUris.appendId(builder, groupCursor.getLong(GROUP_ID_COLUMN_INDEX));
		builder.appendEncodedPath(Contacts.Data.CONTENT_DIRECTORY);
		Uri phoneNumbersUri = builder.build();

		mQueryHandler.startQuery(TOKEN_CHILD, groupCursor.getPosition(), phoneNumbersUri, PHONE_NUMBER_PROJECTION, Phone.MIMETYPE + "=?", new String[] { Phone.CONTENT_ITEM_TYPE },
				null);

		return null;
	}

}