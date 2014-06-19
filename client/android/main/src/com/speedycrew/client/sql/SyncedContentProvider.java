package com.speedycrew.client.sql;

import java.util.List;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteQueryBuilder;
import android.net.Uri;
import android.util.Log;

public class SyncedContentProvider extends ContentProvider {
	private static final String LOGTAG = SyncedContentProvider.class.getName();

	SyncedSQLiteOpenHelper mSyncedSQLiteOpenHelper;

	// used for the UriMacher
	private static final int URI_SEARCH_INDEX = 10;
	private static final int URI_MATCH_INDEX = 20;

	private static final String AUTHORITY = "com.speedycrew.client.sql.synced.contentprovider";
	private static final String BASE_PATH = "/";
	public static final Uri SEARCH_URI = Uri.parse("content://" + AUTHORITY + BASE_PATH + Search.TABLE_NAME);

	private static final UriMatcher sURIMatcher = new UriMatcher(UriMatcher.NO_MATCH);
	static {
		sURIMatcher.addURI(AUTHORITY, Search.TABLE_NAME, URI_SEARCH_INDEX);
		sURIMatcher.addURI(AUTHORITY, Search.TABLE_NAME + "/*/" + Match.TABLE_NAME, URI_MATCH_INDEX);
	}

	@Override
	public boolean onCreate() {
		mSyncedSQLiteOpenHelper = new SyncedSQLiteOpenHelper(getContext());

		return false;
	}

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {

		Log.i(LOGTAG, "query URI[" + uri + "]");

		// Using SQLiteQueryBuilder instead of query() method
		SQLiteQueryBuilder queryBuilder = new SQLiteQueryBuilder();
		List<String> pathSegments = uri.getPathSegments();

		int uriIndex = sURIMatcher.match(uri);
		switch (uriIndex) {
		case URI_SEARCH_INDEX:
			queryBuilder.setTables(Search.TABLE_NAME);
			break;
		case URI_MATCH_INDEX:
			queryBuilder.setTables(Match.TABLE_NAME);
			queryBuilder.appendWhere(Match.SEARCH + "='" + pathSegments.get(1) + "'");
			break;
		default:
			Log.e(LOGTAG, "Unhandled URI[" + uri + "]");
			return null;
		}

		// check if the caller has requested a column which does not exists
		// checkColumns(projection);

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
