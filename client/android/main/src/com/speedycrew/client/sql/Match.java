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

	// I made this up -- ask Thomas what this should be.
	public final static String OWNER = "owner";

}
