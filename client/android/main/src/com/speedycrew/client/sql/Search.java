package com.speedycrew.client.sql;

import android.os.Bundle;

/**
 * Convenience interface representing some static properties of one of our
 * database tables.
 * 
 * @author michael
 * 
 */
public class Search implements android.provider.BaseColumns {

	public final static String TABLE_NAME = "search";

	// HTTP parameter name
	public static final String PARAMETER_NAME = "search_id";

	// Columns names
	public static final String ID = "id";
	public static final String QUERY = "query";
	public static final String SIDE = "side";
	public static final String ADDRESS = "address";
	public static final String POSTCODE = "postcode";
	public static final String CITY = "city";
	public static final String COUNTRY = "country";
	public static final String LONGITUDE = "longitude";
	public static final String LATITUDE = "latitude";
	public static final String RADIUS = "radius";

	// Values
	public static final String VALUE_SEEK = "'SEEK'";
	public static final String VALUE_PROVIDE = "'PROVIDE'";

	private String mSearchId;

	public Search(String searchId) {
		mSearchId = searchId;
	}

	public String getSearchId() {
		return mSearchId;
	}

	public void addToBundle(Bundle bundle) {
		if (mSearchId != null) {
			bundle.putString(PARAMETER_NAME, mSearchId);
		}
	}

	public String toString() {
		return getSearchId();
	}
}
