package com.speedycrew.client.sql;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

public class SyncedSQLiteOpenHelper extends SQLiteOpenHelper {

	private static final int DATABASE_VERSION = 1;
	private static final String DATABASE_NAME = "Synced.db";

	// "The database tables should use the identifier _id for the primary key of the table. Several Android functions rely on this standard."
	// http://www.vogella.com/tutorials/AndroidSQLite/article.html
	private static final String CREATE_SEARCHES = "CREATE TABLE searches ( _id INTEGER PRIMARY KEY AUTOINCREMENT, queryString TEXT NOT NULL );";

	public SyncedSQLiteOpenHelper(Context context) {
		super(context, DATABASE_NAME, null, DATABASE_VERSION);
	}

	@Override
	public void onCreate(SQLiteDatabase db) {
		db.execSQL(CREATE_SEARCHES);
	}

	@Override
	public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
		Log.w(SyncedSQLiteOpenHelper.class.getName(), "Upgrading database from version " + oldVersion + " to " + newVersion + ", which will destroy all old data");
		// TODO: Could be smarter here.
		db.execSQL("DROP TABLE IF EXISTS searches");
		onCreate(db);
	}

}
