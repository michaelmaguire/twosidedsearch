package com.speedycrew.client.sql;

import android.os.Bundle;

public class Crew implements android.provider.BaseColumns {

	public final static String TABLE_NAME = "crew";

	// HTTP parameter name
	public static final String PARAMETER_NAME = "crew_id";

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

	public void addToBundle(Bundle bundle) {
		if (mCrewId != null) {
			bundle.putString(PARAMETER_NAME, mCrewId);
		}
	}

	public String toString() {
		return getCrewId();
	}

}
