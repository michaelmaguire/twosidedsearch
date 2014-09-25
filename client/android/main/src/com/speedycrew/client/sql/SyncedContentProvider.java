package com.speedycrew.client.sql;

import java.util.List;
import java.util.Vector;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.SQLException;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteQueryBuilder;
import android.net.Uri;
import android.os.Bundle;
import android.provider.BaseColumns;
import android.util.Log;

public class SyncedContentProvider extends ContentProvider {
	private static final String LOGTAG = SyncedContentProvider.class.getName();

	SyncedSQLiteOpenHelper mSyncedSQLiteOpenHelper;

	// used for the UriMacher
	private static final int URI_SEARCH_INDEX = 10;
	private static final int URI_MATCH_INDEX = 20;
	private static final int URI_CREW_INDEX = 30;
	private static final int URI_MESSAGE_INDEX = 40;

	private static final String AUTHORITY = "com.speedycrew.client.sql.synced.contentprovider";
	private static final String BASE_PATH = "/";
	public static final Uri BASE_URI = Uri.parse("content://" + AUTHORITY);
	public static final Uri SEARCH_URI = Uri.parse("content://" + AUTHORITY
			+ BASE_PATH + Search.TABLE_NAME);
	public static final Uri CREW_URI = Uri.parse("content://" + AUTHORITY
			+ BASE_PATH + Crew.TABLE_NAME);

	private static final UriMatcher sURIMatcher = new UriMatcher(
			UriMatcher.NO_MATCH);

	/**
	 * SQLite has a handy hidden _rowid_ columns.
	 */
	public static final String SQLITE_ROWID = "_rowid_";

	public static final String METHOD_FETCH_TIMELINE_SEQUENCE = "timeline";
	public static final String METHOD_ON_SYNCHRONIZE_RESPONSE = "synchronize";
	static {
		sURIMatcher.addURI(AUTHORITY, Search.TABLE_NAME, URI_SEARCH_INDEX);
		sURIMatcher.addURI(AUTHORITY, Search.TABLE_NAME + "/*/"
				+ Match.TABLE_NAME, URI_MATCH_INDEX);
		sURIMatcher.addURI(AUTHORITY, Crew.TABLE_NAME, URI_CREW_INDEX);
		sURIMatcher.addURI(AUTHORITY, Message.TABLE_NAME + "/*/"
				+ Message.TABLE_NAME, URI_MESSAGE_INDEX);
	}

	@Override
	public boolean onCreate() {
		mSyncedSQLiteOpenHelper = new SyncedSQLiteOpenHelper(getContext());

		return false;
	}

	@Override
	public Cursor query(Uri uri, String[] projection, String selection,
			String[] selectionArgs, String sortOrder) {

		Log.i(LOGTAG, "query URI[" + uri + "]");

		// For our query below, make sure that we have an '_id' column as
		// required by Google Adapter classes, even if our table doesn't
		// really contain one. To do this, use SQLite's _rowid_.
		//
		// See: http://www.sqlite.org/lang_createtable.html#rowid
		// and:
		// http://stackoverflow.com/questions/11365097/sqlite-create-table-with-an-alias-for-rowid
		Vector<String> newProjectionVector = new Vector<String>();
		for (String passedIn : projection) {
			if (BaseColumns._ID.equalsIgnoreCase(passedIn)) {
				newProjectionVector.add(SQLITE_ROWID + " as _id");
			} else {
				newProjectionVector.add(passedIn);
			}
		}
		String[] newProjection = newProjectionVector
				.toArray(new String[projection.length]);

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
			queryBuilder.appendWhere(Match.SEARCH + "='" + pathSegments.get(1)
					+ "'");
			break;
		case URI_CREW_INDEX:
			queryBuilder.setTables(Crew.TABLE_NAME);
			break;
		case URI_MESSAGE_INDEX:
			queryBuilder.setTables(Message.TABLE_NAME);
			queryBuilder.appendWhere(Message.CREW + "='" + pathSegments.get(1)
					+ "'");
			break;
		default:
			Log.e(LOGTAG, "Unhandled URI[" + uri + "]");
			return null;
		}

		// check if the caller has requested a column which does not exists
		// checkColumns(projection);

		SQLiteDatabase db = mSyncedSQLiteOpenHelper.getReadableDatabase();

		Cursor cursor = queryBuilder.query(db, newProjection, selection,
				selectionArgs, null, null, sortOrder);

		// make sure that potential listeners are getting notified
		cursor.setNotificationUri(getContext().getContentResolver(), uri);

		return cursor;

	}

	@Override
	public Bundle call(String method, String arg, Bundle extras) {
		Log.i(LOGTAG, "call method[" + method + "] arg[" + arg + "]");

		Bundle bundle = null;

		if (METHOD_ON_SYNCHRONIZE_RESPONSE.equals(method)) {
			try {
				JSONObject jsonResponse = new JSONObject(arg);

				Log.i(LOGTAG, "call: jsonResponse[" + jsonResponse + "]");

				JSONArray sqlArray = jsonResponse.getJSONArray("sql");
				if (sqlArray != null) {
					SQLiteDatabase db = mSyncedSQLiteOpenHelper
							.getWritableDatabase();
					String sqlStatement = null;
					int i = 0;
					try {
						db.beginTransaction();

						final int length = sqlArray.length();
						for (i = 0; i < length; ++i) {
							sqlStatement = sqlArray.getString(i);
							Log.i(LOGTAG, "call: SQL sqlStatement["
									+ sqlStatement + "]");
							db.execSQL(sqlStatement);
						}
						db.setTransactionSuccessful();
					} catch (SQLException sqle) {
						Log.e(LOGTAG, "call: SQLException for sqlStatement("
								+ i + ")[" + sqlStatement + "]", sqle);
					} finally {
						db.endTransaction();
					}
				}

			} catch (JSONException jsone) {
				Log.i(LOGTAG,
						"call: error parsing as JSON" + jsone.getMessage());
			}

			// make sure that potential listeners are getting notified
			getContext().getContentResolver().notifyChange(BASE_URI, null);

		} else if (METHOD_FETCH_TIMELINE_SEQUENCE.equals(method)) {
			long timeline = 0;
			long sequence = 0;
			try {
				SQLiteDatabase db = mSyncedSQLiteOpenHelper
						.getReadableDatabase();
				Cursor cursor = db.rawQuery("SELECT * FROM "
						+ Control.TABLE_NAME, null);
				if (cursor.moveToFirst()) {
					timeline = cursor.getLong(cursor
							.getColumnIndex(Control.TIMELINE));
					sequence = cursor.getLong(cursor
							.getColumnIndex(Control.SEQUENCE));
				} else {
					Log.w(LOGTAG, "call: empty cursor, starting sync from 0, 0");
				}
			} catch (Exception e) {
				Log.w(LOGTAG,
						"call: problem querying timeline and sequence, restarting sync from 0, 0",
						e);
			}
			bundle = new Bundle();
			// We'll use column names as bundle keys here.
			bundle.putLong(Control.TIMELINE, timeline);
			bundle.putLong(Control.SEQUENCE, sequence);
		} else {
			Log.w(LOGTAG, "call: unsupported method[" + method + "]");
		}

		return bundle;

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
	public int update(Uri uri, ContentValues values, String selection,
			String[] selectionArgs) {
		// TODO Auto-generated method stub
		return 0;
	}

}
