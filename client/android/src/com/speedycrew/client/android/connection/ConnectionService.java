package com.speedycrew.client.android.connection;

import java.security.KeyStore.PrivateKeyEntry;
import java.security.cert.X509Certificate;
import java.security.cert.X509Extension;

import javax.security.auth.x500.X500Principal;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

public class ConnectionService extends Service {

	private static String LOGTAG = ConnectionService.class.getName();

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

		try {
			PrivateKeyEntry privateKeyEntry = mKeyManager.getPrivateKeyEntry();

			X509Certificate certificate = (X509Certificate) privateKeyEntry.getCertificate();

			// Ddefault toString() is a bit lame -- e.g. doesn't show full CN in
			// Subject.
			String certString = certificate.toString();
			Log.i(LOGTAG, "cert[" + certString + "]");

			// But don't worry, it's there...
			X500Principal subject = certificate.getSubjectX500Principal();
			Log.i(LOGTAG, "subject[" + subject.toString() + "]");

		} catch (Exception e) {
			Log.e(LOGTAG, "onStartCommand getPrivateKeyEntry: " + e.getMessage());
		}

		return Service.START_STICKY;
	}

	@Override
	public IBinder onBind(Intent arg0) {
		// TODO Auto-generated method stub
		return null;
	}

}
