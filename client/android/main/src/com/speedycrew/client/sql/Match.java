package com.speedycrew.client.sql;

/**
 * Convenience interface representing some static properties of one of our
 * database tables.
 * 
 * @author michael
 * 
 */
public interface Match extends android.provider.BaseColumns {

	public final static String TABLE_NAME = "match";

	// Columns names

	public final static String ID = "id";
	// key into Search table.
	public final static String SEARCH = "search";
	public final static String USERNAME = "username";
	public final static String FINGERPRINT = "fingerprint";
	public final static String QUERY = "query";
	public final static String LONGITUDE = "longitude";
	public final static String LATITUDE = "latitude";
	public final static String DISTANCE = "distance";
	public final static String MATCHES = "matches";
	public final static String SCORE = "score";

}
