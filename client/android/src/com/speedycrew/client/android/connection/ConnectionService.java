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

import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Base64;
import android.util.Log;

public class ConnectionService extends Service {

	private static String LOGTAG = ConnectionService.class.getName();

	ArrayList<Messenger> mClients = new ArrayList<Messenger>(); // Keeps track
																// of all
																// current
																// registered
																// clients.
	public static final int MSG_REGISTER_CLIENT = 1;
	public static final int MSG_UNREGISTER_CLIENT = 2;
	public static final int MSG_SET_INT_VALUE = 3;
	public static final int MSG_SET_STRING_VALUE = 4;

	@Override
	public IBinder onBind(Intent intent) {
		return mMessenger.getBinder();
	}

	private class IncomingHandler extends Handler { // Handler of incoming
													// messages from
		// clients.
		@Override
		public void handleMessage(Message msg) {
			switch (msg.what) {
			case MSG_REGISTER_CLIENT:
				mClients.add(msg.replyTo);
				break;
			case MSG_UNREGISTER_CLIENT:
				mClients.remove(msg.replyTo);
				break;
			case MSG_SET_INT_VALUE:
				Log.i(LOGTAG, "handleMessage: " + msg.arg1);
				initiateConnection();
				break;
			default:
				super.handleMessage(msg);
			}
		}
	}

	private void sendMessageToUI(int intvaluetosend) {
		for (int i = mClients.size() - 1; i >= 0; i--) {
			try {
				// Send data as an Integer
				mClients.get(i).send(
						Message.obtain(null, MSG_SET_INT_VALUE, intvaluetosend,
								0));

				// Send data as a String
				Bundle b = new Bundle();
				b.putString("str1", "ab" + intvaluetosend + "cd");
				Message msg = Message.obtain(null, MSG_SET_STRING_VALUE);
				msg.setData(b);
				mClients.get(i).send(msg);

			} catch (RemoteException e) {
				// The client is dead. Remove it from the list; we are going
				// through the list from back to front so this is safe to do
				// inside the loop.
				mClients.remove(i);
			}
		}
	}

	/**
	 * Target we publish for clients to send messages to IncomingHandler.
	 */
	private final Messenger mMessenger = new Messenger(new IncomingHandler());

	// Testing -- works enough to get us a valid HTML response.
	// private static String SPEEDY_URL = "https://www.google.co.uk/";

	// Temporary -- since HTTPS gets us told to piss off -- still can't get past
	// captain cook, though -- must be doing basic auth wrong.
	private static String UPDATE_SPEEDY_URL = "https://dev.speedycrew.com/api/1/update_profile";

	// This was only needed initially before we got SSL working.
	// private static String X_SPEEDY_CREW_USER_ID = "X-SpeedyCrew-UserId";

	private KeyManager mKeyManager;

	/**
	 * Do any one-time initialization here -- this only gets called first time
	 * Service is started.
	 */
	@Override
	public void onCreate() {
		super.onCreate();
		Log.i(LOGTAG, "onCreate");

		try {
			mKeyManager = KeyManager.getInstance();

			Log.i(LOGTAG, "onCreate - ConnectionService is running");
		} catch (Exception e) {
			Log.e(LOGTAG, "onCreate UNABLE TO CREATE KEY MANAGER: " + e);
		}
	}

	/**
	 * This gets called any time anyone sends us an Intent. Don't do any
	 * one-time initialization -- do that in onCreate.
	 */
	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		Log.i(LOGTAG, "onStartCommand");

		return Service.START_STICKY;
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
						httpPost = new HttpPost(UPDATE_SPEEDY_URL);

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
						List<NameValuePair> nameValuePairs = new ArrayList<NameValuePair>(
								2);
						nameValuePairs.add(new BasicNameValuePair("real_name",
								"michael1234"));
						nameValuePairs.add(new BasicNameValuePair("message",
								"MichaelTestMessage"));
						nameValuePairs.add(new BasicNameValuePair("email",
								"speedytest2@michaelmaguire.ca"));

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
	public void onDestroy() {
		super.onDestroy();

		Log.i(LOGTAG, "Service Stopped.");
	}
}
