package com.speedycrew.client.sql;

import android.content.Context;
import android.database.SQLException;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

public class SyncedSQLiteOpenHelper extends SQLiteOpenHelper {
	private static final String LOGTAG = SyncedSQLiteOpenHelper.class.getName();

	private static final int DATABASE_VERSION = 1;
	private static final String DATABASE_NAME = "Synced.db";

	// "The database tables should use the identifier _id for the primary key of the table. Several Android functions rely on this standard."
	// http://www.vogella.com/tutorials/AndroidSQLite/article.html
	private static final String CREATE_SEARCHES = "CREATE TABLE " + Search.TABLE_NAME + " ( " + Search._ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " + Search.IS_HIRING
			+ " INTEGER, " + Search.QUERY_STRING + " TEXT NOT NULL );";
	private static final String CREATE_MATCHES = "CREATE TABLE " + Match.TABLE_NAME + " ( " + Match._ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " + Match.OWNER
			+ " TEXT NOT NULL );";

	public SyncedSQLiteOpenHelper(Context context) {
		super(context, DATABASE_NAME, null, DATABASE_VERSION);
	}

	public static void executeCaughtLoggedSQL(SQLiteDatabase db, String sql) {
		try {
			db.execSQL(sql);
		} catch (SQLException e) {
			Log.e(LOGTAG, "Error executing[" + sql + "]", e);
		}

	}

	@Override
	/**
	 * This will only get called if the database doesn't already exist on device -- to test this, do a full uninstall.
	 */
	public void onCreate(SQLiteDatabase db) {
		executeCaughtLoggedSQL(db, CREATE_SEARCHES);
		executeCaughtLoggedSQL(db, CREATE_MATCHES);

		// Testing
		createTestEntries(db);
	}

	private void createTestEntries(SQLiteDatabase db) {
		executeCaughtLoggedSQL(db, "INSERT INTO search (queryString,isHiring) VALUES ('chef London', 1);");
		executeCaughtLoggedSQL(db, "INSERT INTO search (queryString,isHiring) VALUES ('burger chef London', 1);");
		executeCaughtLoggedSQL(db, "INSERT INTO search (queryString,isHiring) VALUES ('burger chef London', 0);");

	}

	@Override
	public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
		Log.w(LOGTAG, "Upgrading database from version " + oldVersion + " to " + newVersion + ", which will destroy all old data");
		// TODO: Could be smarter here.
		executeCaughtLoggedSQL(db, "DROP TABLE IF EXISTS " + Search.TABLE_NAME);
		executeCaughtLoggedSQL(db, "DROP TABLE IF EXISTS " + Match.TABLE_NAME);
		onCreate(db);
	}

}
