package com.speedycrew.client.android.connection;

import android.os.Bundle;

public class BundleProducer {

	public static Bundle produceProfileUpdateBundle(String real_name,
			String message, String email) {
		Bundle bundle = new Bundle();

		bundle.putString("real_name", real_name);
		bundle.putString("message", message);
		bundle.putString("email", email);

		return bundle;
	}

	public static Bundle produceCreateSearchBundle(boolean provide,
			String queryString) {
		Bundle bundle = new Bundle();

		if (provide) {
			bundle.putString("side", "PROVIDE");
		} else {
			bundle.putString("side", "SEEK");
		}
		bundle.putString("query", queryString);

		return bundle;
	}

}
