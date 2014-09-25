package com.speedycrew.client.sql;

public interface CrewMember extends android.provider.BaseColumns {
	public final static String TABLE_NAME = "crew_member";

	// Columns names
	public static final String CREW = "crew";
	public static final String FINGERPRINT = "fingerprint";
	public static final String STATUS = "status";

}
