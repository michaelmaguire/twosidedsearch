package com.speedycrew.client;

import android.app.Activity;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;

import com.speedycrew.client.util.RequestHelper;

public class MessageListActivity extends Activity {

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_message_list);

		if (savedInstanceState == null) {
			getFragmentManager().beginTransaction()
					.add(R.id.container, new MessageListFragment()).commit();
		}
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {

		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.message_list, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		// Handle action bar item clicks here. The action bar will
		// automatically handle clicks on the Home/Up button, so long
		// as you specify a parent activity in AndroidManifest.xml.
		switch (item.getItemId()) {
		case R.id.action_settings: {
			return true;
		}
		case R.id.action_refresh: {
			try {
				RequestHelper.sendSynchronize(
						SpeedyCrewApplication.getAppContext(), null);
			} catch (Exception e) {
				e.printStackTrace();
			}
			return true;
		}
		default: {
			return super.onOptionsItemSelected(item);
		}

		}
	}
}
