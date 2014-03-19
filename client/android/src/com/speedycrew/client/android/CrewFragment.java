package com.speedycrew.client.android;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ExpandableListView;

public class CrewFragment extends SearchFragment implements View.OnClickListener {
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		// Inflate the layout for this fragment
		View view = inflater.inflate(R.layout.crew_fragment, container, false);

		ExpandableListView elv = (ExpandableListView) view.findViewById(R.id.list);
		elv.setAdapter(new SearchResultsListAdapter());

		Button searchButton = (Button) view.findViewById(R.id.searchButton);
		searchButton.setOnClickListener(this);
		return view;
	}

}