package com.speedycrew.client.android;

import com.speedycrew.client.android.connection.BundleProducer;
import com.speedycrew.client.android.connection.ConnectionService;
import com.speedycrew.client.util.ServiceConnector;

import android.app.ActionBar;
import android.app.ActionBar.Tab;
import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentTransaction;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.os.RemoteException;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

public class MainActivity extends Activity {
	private static String LOGTAG = MainActivity.class.getName();

	static ServiceConnector sConnectionServiceManager;

	public static class SearchFragment extends Fragment implements
			View.OnClickListener {

		@Override
		public void onClick(View view) {
			Log.i(LOGTAG, "SearchFragment onClick");
			EditText searchText = (EditText) ((View) view.getParent())
					.findViewById(R.id.queryString);
			String searchString = searchText.getText().toString();
			Log.i(LOGTAG, "SearchFragment searchString[" + searchString + ']');

			Message msg = Message.obtain();
			msg.obj = new String("1/create_search");
			msg.setData(BundleProducer.produceCreateSearchBundle(
					this instanceof HiringFragment, searchString));
			msg.what = ConnectionService.MSG_MAKE_REQUEST_WITH_PARAMETERS;
			try {
				sConnectionServiceManager.send(msg);
			} catch (RemoteException e) {
				Log.e(LOGTAG, "send error: " + e);
			}
		}
	}

	public static class HiringFragment extends SearchFragment implements
			View.OnClickListener {
		@Override
		public View onCreateView(LayoutInflater inflater, ViewGroup container,
				Bundle savedInstanceState) {
			// Inflate the layout for this fragment
			View view = inflater.inflate(R.layout.hiring_fragment, container,
					false);
			Button searchButton = (Button) view.findViewById(R.id.searchButton);
			searchButton.setOnClickListener(this);
			return view;
		}

	}

	public static class CrewFragment extends SearchFragment implements
			View.OnClickListener {
		@Override
		public View onCreateView(LayoutInflater inflater, ViewGroup container,
				Bundle savedInstanceState) {
			// Inflate the layout for this fragment
			View view = inflater.inflate(R.layout.crew_fragment, container,
					false);
			Button searchButton = (Button) view.findViewById(R.id.searchButton);
			searchButton.setOnClickListener(this);
			return view;
		}

	}

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		setContentView(R.layout.activity_main);

		// use this to start and trigger a service
		Intent serviceStartingIntent = new Intent(
				this,
				com.speedycrew.client.android.connection.ConnectionService.class);
		// potentially add data to the intent
		// serviceStartingIntent.putExtra("KEY1",
		// "Value to be used by the service");
		startService(serviceStartingIntent);

		final ActionBar bar = getActionBar();
		bar.setNavigationMode(ActionBar.NAVIGATION_MODE_TABS);
		bar.setDisplayOptions(0, ActionBar.DISPLAY_SHOW_TITLE);

		bar.addTab(bar
				.newTab()
				.setText("Crew")
				.setTabListener(
						new TabListener<CrewFragment>(this, "crew",
								CrewFragment.class)));
		bar.addTab(bar
				.newTab()
				.setText("Hiring")
				.setTabListener(
						new TabListener<HiringFragment>(this, "hiring",
								HiringFragment.class)));

		if (savedInstanceState != null) {
			bar.setSelectedNavigationItem(savedInstanceState.getInt("tab", 0));
		}

		sConnectionServiceManager = new ServiceConnector(this,
				ConnectionService.class, new Handler() {
					@Override
					public void handleMessage(Message msg) {
						switch (msg.what) {
						case ConnectionService.MSG_JSON_RESPONSE:
							Log.i(LOGTAG, "handleMessage MSG_JSON_RESPONSE: "
									+ msg.arg1);
							break;
						}
					}
				});

		sConnectionServiceManager.start();

	}

	@Override
	protected void onSaveInstanceState(Bundle outState) {
		super.onSaveInstanceState(outState);
		outState.putInt("tab", getActionBar().getSelectedNavigationIndex());
	}

	public static class TabListener<T extends Fragment> implements
			ActionBar.TabListener {
		private final Activity mActivity;
		private final String mTag;
		private final Class<T> mClass;
		private final Bundle mArgs;
		private Fragment mFragment;

		public TabListener(Activity activity, String tag, Class<T> clz) {
			this(activity, tag, clz, null);
		}

		public TabListener(Activity activity, String tag, Class<T> clz,
				Bundle args) {
			mActivity = activity;
			mTag = tag;
			mClass = clz;
			mArgs = args;

			// Check to see if we already have a fragment for this tab, probably
			// from a previously saved state. If so, deactivate it, because our
			// initial state is that a tab isn't shown.
			mFragment = mActivity.getFragmentManager().findFragmentByTag(mTag);
			if (mFragment != null && !mFragment.isDetached()) {
				FragmentTransaction ft = mActivity.getFragmentManager()
						.beginTransaction();
				ft.detach(mFragment);
				ft.commit();
			}
		}

		@Override
		public void onTabSelected(Tab tab, FragmentTransaction ft) {
			if (mFragment == null) {
				mFragment = Fragment.instantiate(mActivity, mClass.getName(),
						mArgs);
				ft.add(android.R.id.content, mFragment, mTag);
			} else {
				ft.attach(mFragment);
			}
		}

		@Override
		public void onTabUnselected(Tab tab, FragmentTransaction ft) {
			if (mFragment != null) {
				ft.detach(mFragment);
			}
		}

		@Override
		public void onTabReselected(Tab tab, FragmentTransaction ft) {
			Toast.makeText(mActivity, "Reselected!", Toast.LENGTH_SHORT).show();
		}

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
		case R.id.action_profile: {
			Intent intent = new Intent(this, ProfileActivity.class);
			startActivity(intent);
			return true;
		}
		case R.id.action_about: {
			Intent intent = new Intent(this, AboutActivity.class);
			startActivity(intent);
			return true;
		}
		default:
			return super.onOptionsItemSelected(item);
		}
	}
}
