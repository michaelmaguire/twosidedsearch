package com.speedycrew.client.sql;

/**
 * Convenience interface representing some static properties of one of our
 * database tables.
 * 
 * @author michael
 * 
 */
public interface Search extends android.provider.BaseColumns {

	public final static String TABLE_NAME = "search";

	// Columns names
	public final static String QUERY_STRING = "queryString";

	public static final String IS_HIRING = "isHiring";
}
