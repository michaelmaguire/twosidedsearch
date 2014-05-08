package com.speedycrew.client.connection;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import org.apache.http.HttpResponse;
import org.apache.http.HttpVersion;
import org.apache.http.NameValuePair;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.params.HttpClientParams;
import org.apache.http.conn.ClientConnectionManager;
import org.apache.http.conn.params.ConnManagerParams;
import org.apache.http.conn.params.ConnPerRoute;
import org.apache.http.conn.params.ConnPerRouteBean;
import org.apache.http.conn.scheme.PlainSocketFactory;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.scheme.SchemeRegistry;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.conn.tsccm.ThreadSafeClientConnManager;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.params.BasicHttpParams;
import org.apache.http.params.HttpConnectionParams;
import org.apache.http.params.HttpParams;
import org.apache.http.params.HttpProtocolParams;
import org.apache.http.util.EntityUtils;
import org.json.JSONObject;

import android.os.Bundle;
import android.os.Message;
import android.os.Messenger;
import android.util.Base64;
import android.util.Log;

import com.google.android.gms.maps.model.LatLng;
import com.speedycrew.client.util.BaseService;

/**
 * This Android service runs in the background and allows UI Activities to issue
 * requests which will then be made as HTTP requests to the SpeedyCrew servers.
 */
public class ConnectionService extends BaseService {

	private static LatLng sLatLng;

	public synchronized static void setLatLng(LatLng latLng) {
		sLatLng = latLng;
	}

	public synchronized static LatLng getLatLng() {
		if (sLatLng == null) {
			return new LatLng(51.5, -0.15);
		}
		return sLatLng;
	}

	public interface Key {
		public static final String SEARCH_ID = "search_id";
		public static final String SIDE = "side";
		public static final String QUERY = "query";
		public static final String VALUE_SIDE_PROVIDE = "PROVIDE";
		public static final String VALUE_SIDE_SEEK = "SEEK";
		public static final String ID = "id";
		public static final String DISTANCE = "distance";
		public static final String USERNAME = "username";
		public static final String EMAIL = "email";
		public static final String ADDRESS = "address";
		public static final String REAL_NAME = "real_name";
		public static final String LONGITUDE = "longitude";
		public static final String LATITUDE = "latitude";
		public static final String POSTCODE = "postcode";
		public static final String CITY = "city";
		public static final String COUNTRY = "country";
		public static final String MESSAGE = "message";
		public static final String SEARCH = "search";
		public static final String STATUS = "status";
		/**
		 * This is actually a SpeedyCrew server parameter name passed right
		 * through.
		 */
		public static final String BUNDLE_KEY_REQUEST_ID = "request_id";
	}

	private static String LOGTAG = ConnectionService.class.getName();

	public static final int MSG_MAKE_REQUEST_WITH_PARAMETERS = 3;
	public static final int MSG_JSON_RESPONSE = 4;

	// Testing -- works enough to get us a valid HTML response.
	// private static String SPEEDY_URL = "https://www.google.co.uk/";

	// Temporary -- since HTTPS gets us told to piss off -- still can't get past
	// captain cook, though -- must be doing basic auth wrong.
	private static final String SPEEDY_API_URL_PREFIX = "https://dev.speedycrew.com/api/";

	// This was only needed initially before we got SSL working.
	// private static String X_SPEEDY_CREW_USER_ID = "X-SpeedyCrew-UserId";

	/**
	 * Begin bundle data items with this prefix if you *DON'T* wish them to be
	 * passed to the server. This is to allow some items to be used in
	 * communication between UI and ConnectionService.
	 */
	public static final String RESERVED_INTERPROCESS_PREFIX = "RESERVED_INTERPROCESS_PREFIX-";

	public static final String BUNDLE_KEY_RESPONSE_JSON = RESERVED_INTERPROCESS_PREFIX
			+ "response-json";

	private void makeRequestWithParameters(final String relativeUrl,
			final Bundle parameters, final Messenger replyTo) {
		new Thread(new Runnable() {
			public void run() {

				JSONObject jsonResponse = new JSONObject();

				try {
					// This is the hex-encoded SHA1 hash of the public key.
					// It's the best thing to use as a unique identifying ID for
					// a user.
					String uniqueUserId = null;
					try {
						uniqueUserId = KeyManager.getInstance().getUserId();
						Log.i(LOGTAG, "uniqueUserId[" + uniqueUserId + "]");
					} catch (Exception e) {
						Log.e(LOGTAG, "makeRequestWithParameters getUserId: "
								+ e.getMessage());
						throw e;
					}

					DefaultHttpClient httpsClient = null;
					try {
						SSLSocketFactory socketFactory = KeyManager
								.getInstance().getSSLSocketFactory();

						// Set parameter data.
						HttpParams params = new BasicHttpParams();
						HttpProtocolParams.setVersion(params,
								HttpVersion.HTTP_1_1);
						HttpProtocolParams.setContentCharset(params, "UTF-8");
						HttpProtocolParams.setUseExpectContinue(params, true);
						HttpProtocolParams.setUserAgent(params,
								"Android SpeedyCrew/1.0.0");

						// Make connection pool.
						ConnPerRoute connPerRoute = new ConnPerRouteBean(12);
						ConnManagerParams.setMaxConnectionsPerRoute(params,
								connPerRoute);
						ConnManagerParams.setMaxTotalConnections(params, 20);

						// Set timeout.
						HttpConnectionParams.setStaleCheckingEnabled(params,
								false);
						HttpConnectionParams.setConnectionTimeout(params,
								30 * 1000);
						HttpConnectionParams.setSoTimeout(params, 30 * 1000);
						HttpConnectionParams.setSocketBufferSize(params, 8192);

						// Some client params.
						HttpClientParams.setRedirecting(params, false);

						SchemeRegistry schReg = new SchemeRegistry();
						schReg.register(new Scheme("http", PlainSocketFactory
								.getSocketFactory(), 80));
						schReg.register(new Scheme("https", socketFactory, 443));
						ClientConnectionManager conMgr = new ThreadSafeClientConnManager(
								params, schReg);
						httpsClient = new DefaultHttpClient(conMgr, params);
					} catch (Exception e) {
						Log.e(LOGTAG,
								"makeRequestWithParameters: error creating DefaultHttpClient: "
										+ e.getMessage());
						throw e;
					}

					HttpPost httpPost = null;
					try {
						httpPost = new HttpPost(SPEEDY_API_URL_PREFIX
								+ relativeUrl);

						// This was only needed initially before we got SSL
						// working.
						// httpPost.addHeader(X_SPEEDY_CREW_USER_ID,
						// uniqueUserId);

						// Needed for **dev**.speedycrew.com
						httpPost.setHeader(
								"Authorization",
								"Basic "
										+ Base64.encodeToString(
												"captain:cook".getBytes(),
												Base64.NO_WRAP));

						// Set post data.

						Set<String> keys = parameters.keySet();

						List<NameValuePair> nameValuePairs = new ArrayList<NameValuePair>(
								keys.size());

						for (String key : keys) {

							if (!key.startsWith(RESERVED_INTERPROCESS_PREFIX)) {
								final String value = parameters.getString(key);
								Log.i(LOGTAG, "Adding to request: key[" + key
										+ "] + value[" + value + "]");
								nameValuePairs.add(new BasicNameValuePair(key,
										value));
							}
						}

						// Not needed with our new public key mechanism -- there
						// will be no subsequent /api/1/login calls anymore, so
						// we're not really creating an account here so much as
						// letting the server know about us...
						// nameValuePairs.add(new BasicNameValuePair("password",
						// "N/A"));

						httpPost.setEntity(new UrlEncodedFormEntity(
								nameValuePairs));

					} catch (Exception e) {
						Log.e(LOGTAG,
								"makeRequestWithParameters: error HttpGet: "
										+ e.getMessage());
						throw e;
					}

					HttpResponse response = null;
					try {
						response = httpsClient.execute(httpPost);
					} catch (Exception e) {
						Log.e(LOGTAG,
								"makeRequestWithParameters: error execute: "
										+ e.getMessage());
						throw e;
					}

					try {
						final int statusCode = response.getStatusLine()
								.getStatusCode();
						if (statusCode < 200 || statusCode >= 300) {
							throw new Exception("HTTP statusCode " + statusCode);
						}

						String resultString = EntityUtils.toString(response
								.getEntity());

						jsonResponse = new JSONObject(resultString);

					} catch (Exception e) {
						Log.e(LOGTAG,
								"makeRequestWithParameters: error reading response: "
										+ e.getMessage());
						throw e;
					}
				} catch (Throwable t) {
					final String errorMessage = "makeRequestWithParameters: "
							+ t.getMessage();
					Log.e(LOGTAG, errorMessage);

					try {
						jsonResponse = new JSONObject();
						jsonResponse.put(Key.STATUS, errorMessage);
						jsonResponse.put(ConnectionService.Key.MESSAGE,
								errorMessage);
					} catch (Exception e) {
						Log.e(LOGTAG, "Unable to report error to UI");
					}
				} finally {
					if (replyTo != null) {
						try {
							final String jsonResponseString = jsonResponse
									.toString();

							Message responseMessage = new Message();
							responseMessage.what = ConnectionService.MSG_JSON_RESPONSE;
							responseMessage.obj = jsonResponseString;
							replyTo.send(responseMessage);
						} catch (Exception e) {
							Log.e(LOGTAG,
									"makeRequestWithParameters: error sending response to calling process: "
											+ e.getMessage());
						}
					}

				}
			}
		}).start();

	}

	@Override
	public void onStartingService() {
		try {
			KeyManager.getInstance();

			Log.i(LOGTAG, "onStartService - ConnectionService is running");
		} catch (Exception e) {
			Log.e(LOGTAG, "onStartService UNABLE TO CREATE KEY MANAGER: " + e);
		}

	}

	@Override
	public void onStoppingService() {
		Log.i(LOGTAG, "onStopService - ConnectionService is stopping");
	}

	@Override
	public void onReceiveMessage(Message message) {
		try {
			switch (message.what) {
			case MSG_MAKE_REQUEST_WITH_PARAMETERS:
				final String relativeUrl = (String) message.obj;
				Log.i(LOGTAG, "onReceiveMessage relativeUrl[" + relativeUrl
						+ "]");

				Bundle bundle = message.getData();
				// Enrich the bundle with geo location -- probably best not
				// to try this on the UI thread.
				LatLng latLng = getLatLng();
				bundle.putString(ConnectionService.Key.LATITUDE,
						Double.toString(latLng.latitude));
				bundle.putString(ConnectionService.Key.LONGITUDE,
						Double.toString(latLng.longitude));

				if (ConnectionService.Key.VALUE_SIDE_SEEK.equals(bundle
						.getString(ConnectionService.Key.SIDE))) {
					// Radius must be present for SEEK, absent for PROVIDE.
					bundle.putString("radius", "5000");
				}

				int requestId = message.arg2;
				final Bundle parameters = message.getData();
				if (!parameters.containsKey(Key.BUNDLE_KEY_REQUEST_ID)) {
					parameters.putString(Key.BUNDLE_KEY_REQUEST_ID,
							Integer.toString(requestId));
				}

				makeRequestWithParameters(relativeUrl, bundle, message.replyTo);
				break;

			}
		} catch (Throwable t) {
			Log.e(LOGTAG, "onReceiveMessage exception: " + t);
		}
	}
}
