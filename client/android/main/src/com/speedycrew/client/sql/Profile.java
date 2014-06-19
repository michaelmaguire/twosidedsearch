package com.speedycrew.client.sql;

public interface Profile extends android.provider.BaseColumns {

	public final static String TABLE_NAME = "profile";

	// Columns names
	public static final String USERNAME = "username";
	public static final String REAL_NAME = "real_name";
	public static final String EMAIL = "email";
	public static final String STATUS = "status";
	public static final String MESSAGE = "message";
	public static final String CREATED = "created";
	public static final String MODIFIED = "modified";
}
