package com.speedycrew.client.sql;

import java.util.List;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteQueryBuilder;
import android.net.Uri;

public class SyncedContentProvider extends ContentProvider {

	SyncedSQLiteOpenHelper mSyncedSQLiteOpenHelper;

	// used for the UriMacher
	private static final int SEARCH_INDEX = 10;
	private static final int MATCH_INDEX = 20;

	private static final String AUTHORITY = "com.speedycrew.client.sql.synced.contentprovider";
	private static final String BASE_PATH = Search.TABLE_NAME;
	public static final Uri CONTENT_URI = Uri.parse("content://" + AUTHORITY + "/" + BASE_PATH);

	private static final UriMatcher sURIMatcher = new UriMatcher(UriMatcher.NO_MATCH);
	static {
		sURIMatcher.addURI(AUTHORITY, BASE_PATH, SEARCH_INDEX);
		sURIMatcher.addURI(AUTHORITY, BASE_PATH + "/#", MATCH_INDEX);
	}

	@Override
	public boolean onCreate() {
		mSyncedSQLiteOpenHelper = new SyncedSQLiteOpenHelper(getContext());

		return false;
	}

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {

		// Uisng SQLiteQueryBuilder instead of query() method
		SQLiteQueryBuilder queryBuilder = new SQLiteQueryBuilder();

		// check if the caller has requested a column which does not exists
		// checkColumns(projection);

		List<String> pathSegments = uri.getPathSegments();

		// Set the table
		queryBuilder.setTables(pathSegments.get(0));

		// queryBuilder.appendWhere("_id" + "=" + uri.getLastPathSegment());

		SQLiteDatabase db = mSyncedSQLiteOpenHelper.getReadableDatabase();

		Cursor cursor = queryBuilder.query(db, projection, selection, selectionArgs, null, null, sortOrder);
		// make sure that potential listeners are getting notified
		cursor.setNotificationUri(getContext().getContentResolver(), uri);

		return cursor;

	}

	@Override
	public String getType(Uri uri) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public Uri insert(Uri uri, ContentValues values) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public int delete(Uri uri, String selection, String[] selectionArgs) {
		// TODO Auto-generated method stub
		return 0;
	}

	@Override
	public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
		// TODO Auto-generated method stub
		return 0;
	}

}
