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

import com.speedycrew.client.sql.Crew;
import com.speedycrew.client.sql.Message;
import com.speedycrew.client.sql.SyncedSQLiteOpenHelper;

public class MessageActivity extends Activity {
	private static final String LOGTAG = MessageActivity.class.getName();

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_message);

		if (savedInstanceState == null) {
			getFragmentManager().beginTransaction()
					.add(R.id.container, new MessageFragment()).commit();
		}
	}

	public static class MessageFragment extends Fragment {
		SyncedSQLiteOpenHelper mSyncedSQLiteOpenHelper;

		public MessageFragment() {

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
			inflater.inflate(R.menu.message, menu);
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

				TextView t = (TextView) getActivity().findViewById(R.id.crew);
				String crewId = t.getText().toString();
				intent.putExtra(Crew.ID, crewId);
				startActivity(intent);
				return true;
			}
			return super.onOptionsItemSelected(item);
		}

		@Override
		public View onCreateView(LayoutInflater inflater, ViewGroup container,
				Bundle savedInstanceState) {
			View rootView = inflater.inflate(R.layout.fragment_message,
					container, false);

			mSyncedSQLiteOpenHelper = new SyncedSQLiteOpenHelper(getActivity());

			String messageId = getActivity().getIntent().getExtras()
					.getString(Message.ID);

			Log.i(LOGTAG, "onCreateView messageId[" + messageId + "]");

			// TODO: I know this sucks from a performance point of view and
			// should be put in some kind of async loader.
			try {
				SQLiteDatabase db = mSyncedSQLiteOpenHelper
						.getReadableDatabase();
				Cursor cursor = db.rawQuery("SELECT * FROM "
						+ Message.TABLE_NAME + " WHERE " + Message.ID + "=?",
						new String[] { messageId });
				if (cursor.moveToFirst()) {

					String read_messageId = cursor.getString(cursor
							.getColumnIndex(Message.ID));
					TextView t = (TextView) rootView.findViewById(R.id.message);
					t.setText(read_messageId);

					String read_sender = cursor.getString(cursor
							.getColumnIndex(Message.SENDER));
					t = (TextView) rootView.findViewById(R.id.sender);
					t.setText(read_sender);

					String read_crew = cursor.getString(cursor
							.getColumnIndex(Message.CREW));
					t = (TextView) rootView.findViewById(R.id.crew);
					t.setText(read_crew);

					String read_created = cursor.getString(cursor
							.getColumnIndex(Message.CREATED));
					t = (TextView) rootView.findViewById(R.id.created);
					t.setText(read_created);

				} else {
					Log.w(LOGTAG, "call: empty cursor, messageId[" + messageId
							+ "] not found");
				}
			} catch (Exception e) {
				Log.w(LOGTAG, "call: problem querying messageId[" + messageId
						+ "]", e);
			}

			return rootView;
		}
	}

}
