package com.speedycrew.client.sql;

import java.util.UUID;

import android.os.Bundle;
import android.util.Log;

public class Message implements android.provider.BaseColumns {
	private static final String LOGTAG = Message.class.getName();

	public final static String TABLE_NAME = "message";

	// Columns names
	public static final String ID = "id";
	public static final String SENDER = "sender";
	public static final String CREW = "crew";
	public static final String BODY = "body";
	public static final String CREATED = "created";

	private String mMessageId;

	public Message(String messageId) {
		mMessageId = messageId;
	}

	public Message() {
		UUID uuid = UUID.randomUUID();
		mMessageId = uuid.toString();
		Log.i(LOGTAG, "Message constructor generating randomUUID mMessageId[" + mMessageId + "]");
	}

	public String getMessageId() {
		return mMessageId;
	}

	public void addToBundle(Bundle bundle) {
		if (mMessageId != null) {
			bundle.putString(ID, mMessageId);
		}
	}

	public String toString() {
		return getMessageId();
	}
}
