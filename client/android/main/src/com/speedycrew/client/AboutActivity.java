package com.speedycrew.client;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.TextView;

import com.speedycrew.client.connection.KeyManager;

public class AboutActivity extends Activity {

	private static final String LOGTAG = AboutActivity.class.getName();

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		setContentView(R.layout.activity_about);

		// This is the hex-encoded SHA1 hash of the public key.
		// It's the best thing to use as a unique identifying ID for
		// a user.
		String uniqueUserId = null;
		try {
			uniqueUserId = KeyManager.getInstance().getUserId();
			Log.i(LOGTAG, "uniqueUserId[" + uniqueUserId + "]");

			TextView t = (TextView) findViewById(R.id.fingerprint);
			t.setText(uniqueUserId);

		} catch (Exception e) {
			Log.e(LOGTAG, "getUserId: " + e.getMessage());
		}

	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.about, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		// Handle item selection
		switch (item.getItemId()) {
		case R.id.action_send_feedback: {
			Intent sendFeedbackViaEmail = new Intent(Intent.ACTION_SEND);
			sendFeedbackViaEmail.setType("text/email");
			sendFeedbackViaEmail.putExtra(Intent.EXTRA_EMAIL,
					new String[] { "android-feedback@speedycrew.com" });
			sendFeedbackViaEmail.putExtra(Intent.EXTRA_SUBJECT, "Feedback");
			sendFeedbackViaEmail.putExtra(Intent.EXTRA_TEXT, "Dear developer,"
					+ "");
			startActivity(Intent.createChooser(sendFeedbackViaEmail,
					"Send Feedback:"));
			return true;
		}
		default:
			return super.onOptionsItemSelected(item);
		}
	}
}
