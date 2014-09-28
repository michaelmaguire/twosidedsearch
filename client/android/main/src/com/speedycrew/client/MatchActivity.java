package com.speedycrew.client;

import android.app.Activity;
import android.app.Fragment;
import android.content.Intent;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.speedycrew.client.sql.Match;
import com.speedycrew.client.sql.SyncedSQLiteOpenHelper;

public class MatchActivity extends Activity {
	private static final String LOGTAG = MatchActivity.class.getName();

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_match);

		if (savedInstanceState == null) {
			getFragmentManager().beginTransaction()
					.add(R.id.container, new MatchFragment()).commit();
		}
	}

	public static class MatchFragment extends Fragment {
		SyncedSQLiteOpenHelper mSyncedSQLiteOpenHelper;

		public MatchFragment() {

		}

		@Override
		public void onCreate(Bundle saved) {
			super.onCreate(saved);
			if (null != saved) {
				// Restore state here
			}
			Log.i(LOGTAG, "onCreate");

			setHasOptionsMenu(true);
		}

		@Override
		public void onCreateOptionsMenu(Menu menu, MenuInflater inflater) {

			// Inflate the menu; this adds items to the action bar if it is
			// present.
			inflater.inflate(R.menu.match, menu);
		}

		@Override
		public boolean onOptionsItemSelected(MenuItem item) {
			// Handle action bar item clicks here. The action bar will
			// automatically handle clicks on the Home/Up button, so long
			// as you specify a parent activity in AndroidManifest.xml.
			int id = item.getItemId();
			if (id == R.id.action_reply) {
				Intent intent = new Intent(getActivity(),
						MessageComposeActivity.class);

				TextView t = (TextView) getActivity().findViewById(
						R.id.fingerprint);
				String fingerprint = t.getText().toString();
				intent.putExtra(Match.FINGERPRINT, fingerprint);
				startActivity(intent);
				return true;
			}
			return super.onOptionsItemSelected(item);
		}

		@Override
		public View onCreateView(LayoutInflater inflater, ViewGroup container,
				Bundle savedInstanceState) {
			View rootView = inflater.inflate(R.layout.fragment_match,
					container, false);

			mSyncedSQLiteOpenHelper = new SyncedSQLiteOpenHelper(getActivity());

			String search = getActivity().getIntent().getExtras()
					.getString(Match.SEARCH);

			String other_search = getActivity().getIntent().getExtras()
					.getString(Match.OTHER_SEARCH);

			Log.i(LOGTAG, "onCreateView search[" + search + "] other_search["
					+ other_search + "]");

			// TODO: I know this sucks from a performance point of view and
			// should be put in some kind of async loader.
			try {
				SQLiteDatabase db = mSyncedSQLiteOpenHelper
						.getReadableDatabase();
				Cursor cursor = db.rawQuery("SELECT * FROM " + Match.TABLE_NAME
						+ " WHERE " + Match.SEARCH + "=? AND "
						+ Match.OTHER_SEARCH + "=?", new String[] { search,
						other_search });
				if (cursor.moveToFirst()) {

					String read_search = cursor.getString(cursor
							.getColumnIndex(Match.SEARCH));
					TextView t = (TextView) rootView.findViewById(R.id.search);
					t.setText(read_search);

					String read_other_search = cursor.getString(cursor
							.getColumnIndex(Match.OTHER_SEARCH));
					t = (TextView) rootView.findViewById(R.id.other_search);
					t.setText(read_other_search);

					String fingerprint = cursor.getString(cursor
							.getColumnIndex(Match.FINGERPRINT));
					t = (TextView) rootView.findViewById(R.id.fingerprint);
					t.setText(fingerprint);

					String username = cursor.getString(cursor
							.getColumnIndex(Match.USERNAME));
					t = (TextView) rootView.findViewById(R.id.username);
					t.setText(username);

					String email = cursor.getString(cursor
							.getColumnIndex(Match.EMAIL));
					t = (TextView) rootView.findViewById(R.id.email);
					t.setText(email);

					String query = cursor.getString(cursor
							.getColumnIndex(Match.QUERY));
					t = (TextView) rootView.findViewById(R.id.query);
					t.setText(query);

					String longitude = cursor.getString(cursor
							.getColumnIndex(Match.LONGITUDE));
					t = (TextView) rootView.findViewById(R.id.longitude);
					t.setText(longitude);

					String latitude = cursor.getString(cursor
							.getColumnIndex(Match.LATITUDE));
					t = (TextView) rootView.findViewById(R.id.latitude);
					t.setText(latitude);

					String distance = cursor.getString(cursor
							.getColumnIndex(Match.DISTANCE));
					t = (TextView) rootView.findViewById(R.id.distance);
					t.setText(distance);

					String score = cursor.getString(cursor
							.getColumnIndex(Match.SCORE));
					t = (TextView) rootView.findViewById(R.id.score);
					t.setText(score);

				} else {
					Log.w(LOGTAG, "call: empty cursor, search[" + search
							+ "] other_search[" + other_search + "] not found");
				}
			} catch (Exception e) {
				Log.w(LOGTAG, "call: problem querying search[" + search
						+ "] other_search[" + other_search + "]", e);
			}

			return rootView;
		}
	}

}
