package com.speedycrew.client.sql;

public class Profile implements android.provider.BaseColumns {

	public final static String TABLE_NAME = "profile";

	private String mFingerprint;

	public Profile(String fingerprint) {
		mFingerprint = fingerprint;
	}

	public String getFingerprint() {
		return mFingerprint;
	}

	public String toString() {
		return getFingerprint();
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
