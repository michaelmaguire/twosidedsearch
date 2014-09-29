package com.speedycrew.client.sql;

import android.os.Bundle;

public class Profile implements android.provider.BaseColumns {

	public final static String TABLE_NAME = "profile";

	// HTTP parameter name
	// TODO: "profile_id"?
	public static final String PARAMETER_NAME = "fingerprint";

	private String mProfileId;

	public Profile(String profileId) {
		mProfileId = profileId;
	}

	public String getProfileId() {
		return mProfileId;
	}

	public void addToBundle(Bundle bundle) {
		if (mProfileId != null) {
			bundle.putString(PARAMETER_NAME, mProfileId);
		}
	}

	public String toString() {
		return getProfileId();
	}

	// Columns names
	public static final String USERNAME = "username";
	public static final String REAL_NAME = "real_name";
	public static final String EMAIL = "email";
	public static final String STATUS = "status";
	public static final String MESSAGE = "message";
	public static final String CREATED = "created";
	public static final String MODIFIED = "modified";
}
