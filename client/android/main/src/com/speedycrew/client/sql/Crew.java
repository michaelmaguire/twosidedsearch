package com.speedycrew.client.sql;

import android.os.Bundle;

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

	public void addToBundle(Bundle bundle) {
		if (mCrewId != null) {
			bundle.putString(com.speedycrew.client.sql.Message.CREW, mCrewId);
		}
	}

	public String toString() {
		return getCrewId();
	}

}
