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
	private static final String CREATE_SEARCH = "CREATE TABLE " + Search.TABLE_NAME + " ( " + Search._ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " + Search.ID + " TEXT NOT NULL, "
			+ Search.QUERY + " TEXT NOT NULL, " + Search.SIDE + " TEXT NOT NULL, " + Search.ADDRESS + " TEXT, " + Search.POSTCODE + " TEXT, " + Search.CITY + " TEXT, "
			+ Search.COUNTRY + " TEXT, " + Search.LONGITUDE + " TEXT NOT NULL, " + Search.LATITUDE + " TEXT NOT NULL, " + Search.RADIUS + " TEXT);";

	private static final String CREATE_MATCH = "CREATE TABLE " + Match.TABLE_NAME + " ( " + Match._ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " + Match.SEARCH + " TEXT NOT NULL, "
			+ Match.OTHER_SEARCH + " TEXT NOT NULL, " + Match.USERNAME + " TEXT, " + Match.FINGERPRINT + " TEXT NOT NULL, " + Match.QUERY + " TEXT NOT NULL, " + Match.LONGITUDE
			+ " TEXT, " + Match.LATITUDE + " TEXT, " + Match.DISTANCE + " TEXT, " + Match.MATCHES + " TEXT, " + Match.SCORE + " TEXT);";

	private static final String CREATE_CONTROL = "CREATE TABLE " + Control.TABLE_NAME + " ( " + Control.TIMELINE + " INTEGER, " + Control.SEQUENCE + " INTEGER);";

	private static final String CREATE_PROFILE = "CREATE TABLE " + Profile.TABLE_NAME + " ( " + Profile._ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " + Profile.USERNAME + " TEXT, "
			+ Profile.REAL_NAME + " TEXT, " + Profile.EMAIL + " TEXT, " + Profile.STATUS + " TEXT, " + Profile.MESSAGE + " TEXT, " + Profile.CREATED + " TEXT, " + Profile.MODIFIED
			+ " TEXT);";

	private static final String CREATE_MESSAGE = "CREATE TABLE " + Message.TABLE_NAME + " ( " + Message._ID + " INTEGER PRIMARY KEY AUTOINCREMENT);";

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
		executeCaughtLoggedSQL(db, CREATE_SEARCH);
		executeCaughtLoggedSQL(db, CREATE_MATCH);
		executeCaughtLoggedSQL(db, CREATE_CONTROL);
		executeCaughtLoggedSQL(db, CREATE_PROFILE);
		executeCaughtLoggedSQL(db, CREATE_MESSAGE);

		// Testing
		// createTestEntries(db);
	}

	private void createTestEntries(SQLiteDatabase db) {
		executeCaughtLoggedSQL(db, "INSERT INTO search (query,side) VALUES ('chef seeker London', 'SEEK');");
		executeCaughtLoggedSQL(db, "INSERT INTO search (query,side) VALUES ('burger chef seeker London', 'SEEK');");
		executeCaughtLoggedSQL(db, "INSERT INTO search (query,side) VALUES ('burger chef provider London', 'PROVIDE');");

		executeCaughtLoggedSQL(db, "INSERT INTO match (searchId, owner) VALUES (2, 'The man');");

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
