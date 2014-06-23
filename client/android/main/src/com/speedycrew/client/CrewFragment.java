package com.speedycrew.client;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ExpandableListView;

import com.speedycrew.client.sql.Search;
import com.speedycrew.client.sql.SyncedContentProvider;

public class CrewFragment extends SearchFragment implements View.OnClickListener {
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		// Inflate the layout for this fragment
		View view = inflater.inflate(R.layout.crew_fragment, container, false);

		mSearchResultsListAdapter = new SearchResultsListAdapter(getActivity());
		mExpandableListView = (ExpandableListView) view.findViewById(R.id.list);
		mExpandableListView.setAdapter(mSearchResultsListAdapter);
		mExpandableListView.setOnGroupClickListener(this);
		mExpandableListView.setOnChildClickListener(this);
		mExpandableListView.setLongClickable(true);
		mExpandableListView.setOnItemLongClickListener(this);

		mQueryHandler = new QueryHandler(getActivity(), mSearchResultsListAdapter);

		// Query for crew searches.
		mQueryHandler.startQuery(TOKEN_GROUP, null, SyncedContentProvider.SEARCH_URI, SEARCH_PROJECTION, Search.SIDE + "=" + Search.VALUE_SEEK, null, null);

		Button searchButton = (Button) view.findViewById(R.id.searchButton);
		searchButton.setOnClickListener(this);
		return view;
	}

}