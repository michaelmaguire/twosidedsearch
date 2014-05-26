package com.speedycrew.client.android.model;

import java.util.Vector;

public class Search {

	public final String mSearchId;
	public final String mQueryString;
	private Vector<SearchResult> mSearchResults = new Vector<SearchResult>();

	public Search(String searchId, String queryString) {
		mSearchId = searchId;
		mQueryString = queryString;
	}

	public void addSearchResult(SearchResult sr) {
		mSearchResults.add(sr);
	}

	public int getNumberOfSearchResults() {
		return mSearchResults.size();
	}

	public SearchResult getSearchResultAt(int i) {
		return mSearchResults.elementAt(i);
	}

	public String toString() {
		return mQueryString;
	}
}
