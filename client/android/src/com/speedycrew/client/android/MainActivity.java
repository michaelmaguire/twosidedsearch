package com.speedycrew.client.android;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;

public class MainActivity extends Activity {

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		setContentView(R.layout.activity_main);

		// use this to start and trigger a service
		Intent serviceStartingIntent = new Intent(this, com.speedycrew.client.android.connection.ConnectionService.class);
		// potentially add data to the intent
		// serviceStartingIntent.putExtra("KEY1",
		// "Value to be used by the service");
		startService(serviceStartingIntent);

	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.main, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		// Handle item selection
		switch (item.getItemId()) {
		case R.id.action_profile:
		{
			Intent intent = new Intent(this, ProfileActivity.class);
			startActivity(intent);
			return true;
		}
		case R.id.action_about:
		{
			Intent intent = new Intent(this, AboutActivity.class);
			startActivity(intent);
			return true;
		}
		default:
			return super.onOptionsItemSelected(item);
		}
	}
}
