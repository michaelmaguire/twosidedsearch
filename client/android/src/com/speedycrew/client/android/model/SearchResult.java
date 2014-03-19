package com.speedycrew.client.android.model;

import org.json.JSONObject;

public class SearchResult {

	private final long mId;
	private final double mDistance;
	private final String mUsername;
	private final String mEmail;
	private final String mAddress;
	private final String mRealName;
	private final double mLongitude;
	private final double mLatitude;
	private final String mPostcode;
	private final String mCity;
	private final String mCountry;

	public SearchResult(JSONObject json) {

		mId = json.getLong("id");
		mDistance = json.getDouble("distance");
		mUsername = json.getString("username");
		mEmail = json.getString("email");
		mAddress = json.getString("address");
		mRealName = json.getString("real_name");
		mLongitude = json.getDouble("longitude");
		mLatitude = json.getDouble("latitude");
		mPostcode = json.getString("postcode");
		mCity = json.getString("city");
		mCountry = json.getString("country");
	}

	public String toString() {
		return mUsername + " " + mEmail;
	}

}
