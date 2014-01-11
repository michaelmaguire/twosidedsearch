package com.speedycrew.client.android.connection;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.Authenticator;
import java.net.PasswordAuthentication;
import java.util.ArrayList;
import java.util.List;

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

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Base64;
import android.util.Log;

public class ConnectionService extends Service {

	private static String LOGTAG = ConnectionService.class.getName();

	// Intended -- but currently we get told to piss off:
	// private static String SPEEDY_URL =
	// "http://dev.speedycrew.com/api/1/create";

	// Testing -- works enough to get us a valid HTML response.
	// private static String SPEEDY_URL = "https://www.google.co.uk/";

	// Temporary -- since HTTPS gets us told to piss off -- still can't get past
	// captain cook, though -- must be doing basic auth wrong.
	private static String SPEEDY_URL = "https://dev.speedycrew.com/api/1/create";

	//private static String X_SPEEDY_CREW_USER_ID = "X-SpeedyCrew-UserId";

	private KeyManager mKeyManager;

	/**
	 * Do any one-time initialization here -- this only gets called first time
	 * Service is started.
	 */
	@Override
	public void onCreate() {
		Log.i(LOGTAG, "onCreate");

		try {
			mKeyManager = KeyManager.getInstance();
		} catch (Exception e) {
			Log.e(LOGTAG, "onCreate UNABLE TO CREATE KEY MANAGER");
		}

	}

	/**
	 * This gets called any time anyone sends us an Intent. Don't do any
	 * one-time initialization -- do that in onCreate.
	 */
	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		Log.i(LOGTAG, "onStartCommand");

		initiateConnection();

		return Service.START_STICKY;
	}

	@Override
	public IBinder onBind(Intent arg0) {
		// TODO Auto-generated method stub
		return null;
	}

	private void initiateConnection() {
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
						Log.e(LOGTAG, "initiateConnection getUserId: " + e.getMessage());
						throw e;
					}

					DefaultHttpClient httpsClient = null;
					try {
						SSLSocketFactory socketFactory = mKeyManager.getSSLSocketFactory();

						// Set parameter data.
						HttpParams params = new BasicHttpParams();
						HttpProtocolParams.setVersion(params, HttpVersion.HTTP_1_1);
						HttpProtocolParams.setContentCharset(params, "UTF-8");
						HttpProtocolParams.setUseExpectContinue(params, true);
						HttpProtocolParams.setUserAgent(params, "Android SpeedyCrew/1.0.0");

						// Make connection pool.
						ConnPerRoute connPerRoute = new ConnPerRouteBean(12);
						ConnManagerParams.setMaxConnectionsPerRoute(params, connPerRoute);
						ConnManagerParams.setMaxTotalConnections(params, 20);

						// Set timeout.
						HttpConnectionParams.setStaleCheckingEnabled(params, false);
						HttpConnectionParams.setConnectionTimeout(params, 30 * 1000);
						HttpConnectionParams.setSoTimeout(params, 30 * 1000);
						HttpConnectionParams.setSocketBufferSize(params, 8192);

						// Some client params.
						HttpClientParams.setRedirecting(params, false);

						SchemeRegistry schReg = new SchemeRegistry();
						schReg.register(new Scheme("http", PlainSocketFactory.getSocketFactory(), 80));
						schReg.register(new Scheme("https", socketFactory, 443));
						ClientConnectionManager conMgr = new ThreadSafeClientConnManager(params, schReg);
						httpsClient = new DefaultHttpClient(conMgr, params);
					} catch (Exception e) {
						Log.e(LOGTAG, "initiateConnection: error creating DefaultHttpClient: " + e.getMessage());
						throw e;
					}

					HttpPost httpPost = null;
					try {
						httpPost = new HttpPost(SPEEDY_URL);

						//httpPost.addHeader(X_SPEEDY_CREW_USER_ID, uniqueUserId);

						// Try adding in our test dev server credentials.
						// Hmmm. Still not doing this right... getting "401
						// Authorization Required".
						
						httpPost.setHeader("Authorization", "Basic " + Base64.encodeToString("captain:cook".getBytes(), Base64.NO_WRAP));

						// Set post data.
						List<NameValuePair> nameValuePairs = new ArrayList<NameValuePair>(2);
						nameValuePairs.add(new BasicNameValuePair("username", "michael1234"));
						nameValuePairs.add(new BasicNameValuePair("firstname", "MichaelTest"));
						nameValuePairs.add(new BasicNameValuePair("lastname", "LastnameTest"));
						nameValuePairs.add(new BasicNameValuePair("email", "speedytest@michaelmaguire.ca"));

						// Not needed with our new public key mechanism -- there
						// will be no subsequent /api/1/login calls anymore, so
						// we're not really creating an account here so much as
						// letting the server know about us...
						// nameValuePairs.add(new BasicNameValuePair("password",
						// "N/A"));

						httpPost.setEntity(new UrlEncodedFormEntity(nameValuePairs));

					} catch (Exception e) {
						Log.e(LOGTAG, "initiateConnection: error HttpGet: " + e.getMessage());
						throw e;
					}

					HttpResponse response = null;
					try {
						response = httpsClient.execute(httpPost);
					} catch (Exception e) {
						Log.e(LOGTAG, "initiateConnection: error execute: " + e.getMessage());
						throw e;
					}

					try {
						HttpEntity httpEntity = response.getEntity();
						InputStream is = httpEntity.getContent();
						BufferedReader read = new BufferedReader(new InputStreamReader(is));
						String query = null;
						while ((query = read.readLine()) != null)
							System.out.println(query);

					} catch (Exception e) {
						Log.e(LOGTAG, "initiateConnection: error reading response: " + e.getMessage());
						throw e;
					}
				} catch (Throwable t) {
					Log.e(LOGTAG, "initiateConnection: " + t.getMessage());
				}
			}
		}).start();

	}

}
