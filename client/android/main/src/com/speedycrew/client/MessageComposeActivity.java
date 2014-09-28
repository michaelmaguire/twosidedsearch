package com.speedycrew.client;

import org.json.JSONObject;

import android.app.Activity;
import android.app.Fragment;
import android.os.Bundle;
import android.os.Handler;
import android.os.ResultReceiver;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import com.speedycrew.client.connection.ConnectionService;
import com.speedycrew.client.connection.ConnectionService.Key;
import com.speedycrew.client.sql.Crew;
import com.speedycrew.client.sql.Match;
import com.speedycrew.client.sql.Profile;
import com.speedycrew.client.util.RequestHelper;

public class MessageComposeActivity extends Activity {
	private static final String LOGTAG = MessageComposeActivity.class.getName();

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_message_compose);

		if (savedInstanceState == null) {
			getFragmentManager().beginTransaction().add(R.id.container, new MessageComposeFragment()).commit();
		}
	}

	public static class MessageComposeFragment extends Fragment {

		public MessageComposeFragment() {
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
			inflater.inflate(R.menu.message_compose, menu);
		}

		@Override
		public boolean onOptionsItemSelected(MenuItem item) {
			// Handle action bar item clicks here. The action bar will
			// automatically handle clicks on the Home/Up button, so long
			// as you specify a parent activity in AndroidManifest.xml.
			int id = item.getItemId();
			if (id == R.id.action_send) {

				// One of these two may be null, depending on whether
				// we're replying to a user fingerprint specified in a
				// match, or whether we're adding to an existing crew
				// chat.
				Crew crew = new Crew(getActivity().getIntent().getExtras().getString(Crew.ID));
				Profile fingerprint = new Profile(getActivity().getIntent().getExtras().getString(Match.FINGERPRINT));

				TextView t = (TextView) getActivity().findViewById(R.id.body);
				String bodyTextString = t.getText().toString();

				Log.i(LOGTAG, "onOptionsItemSelected crewId[" + crew + "] fingerprint[" + fingerprint + "] bodyTextString[" + bodyTextString + "]");

				try {
					RequestHelper.sendMessage(getActivity(), crew, fingerprint, null /*
																					 * asks
																					 * it
																					 * to
																					 * generate
																					 * for
																					 * us
																					 */, bodyTextString, new ResultReceiver(new Handler()) {

						@Override
						public void onReceiveResult(int resultCode, Bundle resultData) {
							Log.i(LOGTAG, "onReceiveResult from createMessage resultCode[" + resultCode + "] resultData[" + resultData + "]");

							try {
								String jsonString = resultData.getString(ConnectionService.BUNDLE_KEY_JSON_RESPONSE);
								JSONObject responseJson = new JSONObject(jsonString);
								String status = responseJson.getString(Key.STATUS);
								if (!"OK".equalsIgnoreCase(status)) {
									String errorMessage = responseJson.getString(ConnectionService.Key.MESSAGE);

									Toast.makeText(getActivity(), errorMessage, Toast.LENGTH_SHORT).show();

								}
							} catch (Exception e) {
								Log.e(LOGTAG, "onClick get results error: " + e);
							}

						}
					});
				} catch (Exception e) {
					Log.e(LOGTAG, "onClick error: " + e);
				}

				return true;
			}
			return super.onOptionsItemSelected(item);
		}

		@Override
		public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
			View rootView = inflater.inflate(R.layout.fragment_message_compose, container, false);

			String crewId = getActivity().getIntent().getExtras().getString(Crew.ID);

			String fingerprint = getActivity().getIntent().getExtras().getString(Match.FINGERPRINT);

			Log.i(LOGTAG, "onCreateView crewId[" + crewId + "] fingerprint[" + fingerprint + "]");

			return rootView;
		}
	}

}
