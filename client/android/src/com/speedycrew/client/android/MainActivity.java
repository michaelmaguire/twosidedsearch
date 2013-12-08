package com.speedycrew.client.android;

import android.os.Bundle;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.view.Menu;

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

}
