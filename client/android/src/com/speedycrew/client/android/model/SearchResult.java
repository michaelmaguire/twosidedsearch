package com.speedycrew.client.android.model;

import org.json.JSONObject;

import com.speedycrew.client.android.connection.ConnectionService;

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

		mId = json.getLong(ConnectionService.Key.ID);
		mDistance = json.getDouble(ConnectionService.Key.DISTANCE);
		mUsername = json.getString(ConnectionService.Key.USERNAME);
		mEmail = json.getString(ConnectionService.Key.EMAIL);
		mAddress = json.getString(ConnectionService.Key.ADDRESS);
		mRealName = json.getString(ConnectionService.Key.REAL_NAME);
		mLongitude = json.getDouble(ConnectionService.Key.LONGITUDE);
		mLatitude = json.getDouble(ConnectionService.Key.LATITUDE);
		mPostcode = json.getString(ConnectionService.Key.POSTCODE);
		mCity = json.getString(ConnectionService.Key.CITY);
		mCountry = json.getString(ConnectionService.Key.COUNTRY);
	}

	public String toString() {
		return mUsername + " " + mRealName + " " + mEmail + " " + mCity;
	}

}
