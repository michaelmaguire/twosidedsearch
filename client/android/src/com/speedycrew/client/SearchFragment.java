package com.speedycrew.client;

import java.util.Vector;

import org.json.JSONArray;
import org.json.JSONObject;

import android.app.Fragment;
import android.content.Context;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import com.speedycrew.client.android.model.Search;
import com.speedycrew.client.android.model.SearchResult;
import com.speedycrew.client.connection.ConnectionService;
import com.speedycrew.client.connection.ConnectionService.Key;
import com.speedycrew.client.util.RequestHelperServiceConnector;

public class SearchFragment extends Fragment implements View.OnClickListener {
	private static final String LOGTAG = SearchFragment.class.getName();

	private RequestHelperServiceConnector mRequestHelperServiceConnector;

	protected SearchResultsListAdapter mSearchResultsListAdapter;

	Vector<Search> mSearchGroups = new Vector<Search>();

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

	void addSearch(final Search search) {
		getActivity().runOnUiThread(new Runnable() {
			public void run() {
				mSearchGroups.add(search);
				mSearchResultsListAdapter.notifyDataSetChanged();
			}
		});
	}

	void addSearchResultToSearch(final Search search, final SearchResult searchResult) {
		getActivity().runOnUiThread(new Runnable() {
			public void run() {
				search.addSearchResult(searchResult);
				mSearchResultsListAdapter.notifyDataSetChanged();
			}
		});
	}

	private class SearchResultsHandlerCallback implements Handler.Callback {

		private static final String JSON_KEY_RESULTS = "results";
		private final Search mSearch;

		SearchResultsHandlerCallback(Search search) {
			mSearch = search;
		}

		@Override
		public boolean handleMessage(Message responseMessage) {
			try {
				switch (responseMessage.what) {
				case ConnectionService.MSG_JSON_RESPONSE:
					final String responseString = responseMessage.obj.toString();

					Log.i(LOGTAG, "handleMessage search results MSG_JSON_RESPONSE: " + responseString);

					{
						JSONObject responseJson = new JSONObject(responseString);
						String status = responseJson.getString(Key.STATUS);
						if (!"OK".equalsIgnoreCase(status)) {
							String errorMessage = responseJson.getString(Key.MESSAGE);

							Toast.makeText(getActivity(), errorMessage, Toast.LENGTH_SHORT).show();

						} else {

							JSONArray results = responseJson.getJSONArray(JSON_KEY_RESULTS);

							for (int i = 0; i < results.length(); ++i) {
								SearchResult sr = new SearchResult(results.getJSONObject(i));
								addSearchResultToSearch(mSearch, sr);
							}

						}
					}

					return true;
					// break;
				}
			} catch (Exception e) {
				Log.i(LOGTAG, "SearchResultsHandlerCallback handleMessage error: " + e);
			}
			return false;
		}
	}

	@Override
	public void onClick(View view) {
		Log.i(LOGTAG, "SearchFragment onClick");
		EditText searchText = (EditText) ((View) view.getParent()).findViewById(R.id.queryString);
		final String queryString = searchText.getText().toString();
		Log.i(LOGTAG, "SearchFragment queryString[" + queryString + ']');

		try {
			mRequestHelperServiceConnector.createSearch(queryString, this instanceof HiringFragment, new Handler.Callback() {
				@Override
				public boolean handleMessage(Message responseMessage) {
					switch (responseMessage.what) {
					case ConnectionService.MSG_JSON_RESPONSE:
						try {
							final String responseString = responseMessage.obj.toString();
							Log.i(LOGTAG, "handleMessage create search MSG_JSON_RESPONSE: " + responseString);

							JSONObject responseJson = new JSONObject(responseString);
							String status = responseJson.getString(Key.STATUS);
							if (!"OK".equalsIgnoreCase(status)) {
								String errorMessage = responseJson.getString(ConnectionService.Key.MESSAGE);

								Toast.makeText(getActivity(), errorMessage, Toast.LENGTH_SHORT).show();

							} else {
								String searchId = responseJson.getString(ConnectionService.Key.SEARCH_ID);

								Search search = new Search(searchId, queryString);

								addSearch(search);

								mRequestHelperServiceConnector.getSearchResults(searchId, new SearchResultsHandlerCallback(search));
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

		@Override
		public int getGroupCount() {
			return mSearchGroups.size();
		}

		@Override
		public int getChildrenCount(int i) {
			return mSearchGroups.elementAt(i).getNumberOfSearchResults();
		}

		@Override
		public Object getGroup(int i) {
			return mSearchGroups.elementAt(i);
		}

		@Override
		public Object getChild(int i, int i1) {
			return mSearchGroups.elementAt(i).getSearchResultAt(i1);
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
		public View getGroupView(int groupPosition, boolean isExpanded, View convertView, ViewGroup parent) {
			String searchName = getGroup(groupPosition).toString();
			if (convertView == null) {
				LayoutInflater inflater = (LayoutInflater) getActivity().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
				convertView = inflater.inflate(R.layout.search_group, null);
			}
			TextView item = (TextView) convertView.findViewById(R.id.queryString);
			item.setTypeface(null, Typeface.BOLD);
			item.setText(searchName);
			return convertView;
		}

		@Override
		public View getChildView(final int groupPosition, final int childPosition, boolean isLastChild, View convertView, ViewGroup parent) {
			final String searchResult = getChild(groupPosition, childPosition).toString();
			LayoutInflater inflater = getActivity().getLayoutInflater();

			if (convertView == null) {
				convertView = inflater.inflate(R.layout.search_result_child, null);
			}

			TextView item = (TextView) convertView.findViewById(R.id.result);

			convertView.setOnClickListener(new OnClickListener() {

				public void onClick(View v) {
					Log.e(LOGTAG, "onClick for search result: " + searchResult);

				}
			});

			item.setText(searchResult);
			return convertView;
		}

		@Override
		public boolean isChildSelectable(int i, int i1) {
			return true;
		}

	}

}