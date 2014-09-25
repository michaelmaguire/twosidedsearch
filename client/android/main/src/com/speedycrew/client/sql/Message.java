package com.speedycrew.client.sql;

public interface Message extends android.provider.BaseColumns {
	public final static String TABLE_NAME = "message";

	// Columns names
	public static final String ID = "id";
	public static final String SENDER = "sender";
	public static final String CREW = "crew";
	public static final String BODY = "body";
	public static final String CREATED = "created";
}
