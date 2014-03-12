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

}
