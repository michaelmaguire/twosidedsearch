package com.speedycrew.client.android.connection;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.HttpVersion;
import org.apache.http.client.methods.HttpGet;
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
import org.apache.http.params.BasicHttpParams;
import org.apache.http.params.HttpConnectionParams;
import org.apache.http.params.HttpParams;
import org.apache.http.params.HttpProtocolParams;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

public class ConnectionService extends Service {

	private static String LOGTAG = ConnectionService.class.getName();

	private static String SPEEDY_URL = "https://dev.speedycrew.com/api/1/login";
	// private static String SPEEDY_URL = "https://www.google.co.uk/";

	private static String X_SPEEDY_CREW_USER_ID = "X-SpeedyCrew-UserId";

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
					String uniqueUserId = mKeyManager.getUserId();
					Log.i(LOGTAG, "uniqueUserId[" + uniqueUserId + "]");
					try {

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
						params.setParameter(X_SPEEDY_CREW_USER_ID, uniqueUserId);

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

					HttpGet httpGet = null;
					try {
						httpGet = new HttpGet(SPEEDY_URL);
					} catch (Exception e) {
						Log.e(LOGTAG, "initiateConnection: error HttpGet: " + e.getMessage());
						throw e;
					}

					HttpResponse response = null;
					try {
						response = httpsClient.execute(httpGet);
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
						Log.e(LOGTAG, "initiateConnection: error making request: " + e.getMessage());
						throw e;
					}
				} catch (Throwable t) {
					Log.e(LOGTAG, "initiateConnection: " + t.getMessage());
				}
			}
		}).start();

	}

}
