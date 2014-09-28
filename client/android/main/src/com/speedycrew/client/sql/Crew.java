package com.speedycrew.client.sql;

public class Crew implements android.provider.BaseColumns {

	public final static String TABLE_NAME = "crew";

	// Columns names
	public static final String ID = "id";
	public static final String NAME = "name";

	private String mCrewId;

	public Crew(String crewId) {
		mCrewId = crewId;
	}

	public String getCrewId() {
		return mCrewId;
	}

	public String toString() {
		return getCrewId();
	}

}
