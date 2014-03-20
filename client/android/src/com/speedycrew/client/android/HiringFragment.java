package com.speedycrew.client.android;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ExpandableListView;

public class HiringFragment extends SearchFragment implements View.OnClickListener {
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		// Inflate the layout for this fragment
		View view = inflater.inflate(R.layout.hiring_fragment, container, false);

		mSearchResultsListAdapter = new SearchResultsListAdapter();
		ExpandableListView elv = (ExpandableListView) view.findViewById(R.id.list);
		elv.setAdapter(mSearchResultsListAdapter);

		Button searchButton = (Button) view.findViewById(R.id.searchButton);
		searchButton.setOnClickListener(this);
		return view;
	}

}