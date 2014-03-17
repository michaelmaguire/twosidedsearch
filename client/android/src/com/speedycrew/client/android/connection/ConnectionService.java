package com.speedycrew.client.android.connection;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import org.apache.http.HttpEntity;
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

import android.os.Bundle;
import android.os.Message;
import android.util.Base64;
import android.util.Log;

import com.speedycrew.client.util.BaseService;

/**
 * This Android service runs in the background and allows UI Activities to issue
 * requests which will then be made as HTTP requests to the SpeedyCrew servers.
 */
public class ConnectionService extends BaseService {

	private static String LOGTAG = ConnectionService.class.getName();

	public static final int MSG_MAKE_REQUEST_WITH_PARAMETERS = 3;
	public static final int MSG_JSON_RESPONSE = 4;

	// Testing -- works enough to get us a valid HTML response.
	// private static String SPEEDY_URL = "https://www.google.co.uk/";

	// Temporary -- since HTTPS gets us told to piss off -- still can't get past
	// captain cook, though -- must be doing basic auth wrong.
	private static String SPEEDY_API_URL_PREFIX = "https://dev.speedycrew.com/api/";

	// This was only needed initially before we got SSL working.
	// private static String X_SPEEDY_CREW_USER_ID = "X-SpeedyCrew-UserId";

	private KeyManager mKeyManager;

	private void makeRequestWithParameters(final String relativeUrl,
			final Bundle parameters) {
		new Thread(new Runnable() {
			public void run() {
				try {
					// This is the hex-encoded SHA1 hash of the public key.
					// It's the best thing to use as a unique identifying ID for
					// a user.
					String uniqueUserId = null;
					try {
						uniqueUserId = mKeyManager.getUserId();
						Log.i(LOGTAG, "uniqueUserId[" + uniqueUserId + "]");
					} catch (Exception e) {
						Log.e(LOGTAG,
								"initiateConnection getUserId: "
										+ e.getMessage());
						throw e;
					}

					DefaultHttpClient httpsClient = null;
					try {
						SSLSocketFactory socketFactory = mKeyManager
								.getSSLSocketFactory();

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
								"initiateConnection: error creating DefaultHttpClient: "
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
							nameValuePairs.add(new BasicNameValuePair(key,
									parameters.getString(key)));
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
								"initiateConnection: error HttpGet: "
										+ e.getMessage());
						throw e;
					}

					HttpResponse response = null;
					try {
						response = httpsClient.execute(httpPost);
					} catch (Exception e) {
						Log.e(LOGTAG,
								"initiateConnection: error execute: "
										+ e.getMessage());
						throw e;
					}

					try {
						HttpEntity httpEntity = response.getEntity();
						InputStream is = httpEntity.getContent();
						BufferedReader read = new BufferedReader(
								new InputStreamReader(is));
						String query = null;
						while ((query = read.readLine()) != null)
							System.out.println(query);

					} catch (Exception e) {
						Log.e(LOGTAG,
								"initiateConnection: error reading response: "
										+ e.getMessage());
						throw e;
					}
				} catch (Throwable t) {
					Log.e(LOGTAG, "initiateConnection: " + t.getMessage());
				}
			}
		}).start();

	}

	@Override
	public void onStartingService() {
		try {
			mKeyManager = KeyManager.getInstance();

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
	public void onReceiveMessage(Message msg) {

		switch (msg.what) {
		case MSG_MAKE_REQUEST_WITH_PARAMETERS:
			String relativeUrl = (String) msg.obj;
			Log.i(LOGTAG, "onReceiveMessage relativeUrl[" + relativeUrl + "]");
			
			Bundle bundle = msg.getData();
			
			// Enrich the bundle with geo location -- probably best not
			// to try this on the UI thread.
			bundle.putString("longitude", "-0.15");
			bundle.putString("latitude", "51.5");
			bundle.putString("radius", "5000");
						
			makeRequestWithParameters((String) msg.obj, bundle);
			break;

		}
	}
}
