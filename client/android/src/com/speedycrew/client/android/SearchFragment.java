package com.speedycrew.client.android;

import org.json.JSONObject;

import android.app.Fragment;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import com.speedycrew.client.android.connection.ConnectionService;
import com.speedycrew.client.util.RequestHelperServiceConnector;

public class SearchFragment extends Fragment implements View.OnClickListener {
	private static final String LOGTAG = SearchFragment.class.getName();

	private RequestHelperServiceConnector mRequestHelperServiceConnector;

	@Override
	public void onCreate(Bundle saved) {
		super.onCreate(saved);
		if (null != saved) {
			// Restore state here
		}
		Log.i(LOGTAG, "onCreate");

		mRequestHelperServiceConnector = new RequestHelperServiceConnector(getActivity(), ConnectionService.class);

		mRequestHelperServiceConnector.start();
	}

	private class SearchResultsHandlerCallback implements Handler.Callback {
		@Override
		public boolean handleMessage(Message responseMessage) {
			switch (responseMessage.what) {
			case ConnectionService.MSG_JSON_RESPONSE:
				final String responseString = responseMessage.obj.toString();

				Log.i(LOGTAG, "handleMessage search results MSG_JSON_RESPONSE: " + responseString);

				{
					JSONObject responseJson = new JSONObject(responseString);
					String status = responseJson.getString(ConnectionService.JSON_KEY_STATUS);
					if (!"OK".equalsIgnoreCase(status)) {
						String errorMessage = responseJson.getString(ConnectionService.JSON_KEY_MESSAGE);

						Toast.makeText(getActivity(), errorMessage, Toast.LENGTH_SHORT).show();

					} else {

					}
				}

				return true;
				// break;

			}
			return false;
		}
	}

	@Override
	public void onClick(View view) {
		Log.i(LOGTAG, "SearchFragment onClick");
		EditText searchText = (EditText) ((View) view.getParent()).findViewById(R.id.queryString);
		String searchString = searchText.getText().toString();
		Log.i(LOGTAG, "SearchFragment searchString[" + searchString + ']');

		try {
			mRequestHelperServiceConnector.createSearch(searchString, this instanceof HiringFragment, new Handler.Callback() {
				@Override
				public boolean handleMessage(Message responseMessage) {
					switch (responseMessage.what) {
					case ConnectionService.MSG_JSON_RESPONSE:
						try {
							final String responseString = responseMessage.obj.toString();
							Log.i(LOGTAG, "handleMessage create search MSG_JSON_RESPONSE: " + responseString);

							JSONObject responseJson = new JSONObject(responseString);
							String status = responseJson.getString(ConnectionService.JSON_KEY_STATUS);
							if (!"OK".equalsIgnoreCase(status)) {
								String errorMessage = responseJson.getString(ConnectionService.JSON_KEY_MESSAGE);

								Toast.makeText(getActivity(), errorMessage, Toast.LENGTH_SHORT).show();

							} else {
								String searchId = responseJson.getString(RequestHelperServiceConnector.JSON_KEY_SEARCH_ID);

								mRequestHelperServiceConnector.getSearchResults(searchId, new SearchResultsHandlerCallback());
							}
						} catch (Exception e) {
							Log.e(LOGTAG, "onClick get results error: " + e);
						}

						return true;
						// break;
					}
					return false;
				}
			});
		} catch (Exception e) {
			Log.e(LOGTAG, "onClick error: " + e);
		}
	}

	public class SearchResultsListAdapter extends BaseExpandableListAdapter {

		private String[] groups = { "People Names", "Dog Names", "Cat Names", "Fish Names" };

		private String[][] children = { { "Arnold", "Barry", "Chuck", "David" }, { "Ace", "Bandit", "Cha-Cha", "Deuce" }, { "Fluffy", "Snuggles" }, { "Goldy", "Bubbles" } };

		@Override
		public int getGroupCount() {
			return groups.length;
		}

		@Override
		public int getChildrenCount(int i) {
			return children[i].length;
		}

		@Override
		public Object getGroup(int i) {
			return groups[i];
		}

		@Override
		public Object getChild(int i, int i1) {
			return children[i][i1];
		}

		@Override
		public long getGroupId(int i) {
			return i;
		}

		@Override
		public long getChildId(int i, int i1) {
			return i1;
		}

		@Override
		public boolean hasStableIds() {
			return true;
		}

		@Override
		public View getGroupView(int i, boolean b, View view, ViewGroup viewGroup) {
			TextView textView = new TextView(SearchFragment.this.getActivity());
			textView.setText(getGroup(i).toString());
			return textView;
		}

		@Override
		public View getChildView(int i, int i1, boolean b, View view, ViewGroup viewGroup) {
			TextView textView = new TextView(SearchFragment.this.getActivity());
			textView.setText(getChild(i, i1).toString());
			return textView;
		}

		@Override
		public boolean isChildSelectable(int i, int i1) {
			return true;
		}

	}

}