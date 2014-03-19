package com.speedycrew.client.util;

import java.util.ArrayList;

import android.app.Service;
import android.content.Intent;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;

public abstract class BaseService extends Service {

	private static String LOGTAG = BaseService.class.getName();

	static final int MSG_REGISTER_CLIENT = 10001;
	static final int MSG_UNREGISTER_CLIENT = 10002;

	ArrayList<Messenger> mClients = new ArrayList<Messenger>();

	private final Messenger mMessenger = new Messenger(new Handler() {

		public void handleMessage(Message msg) {
			switch (msg.what) {
			case MSG_REGISTER_CLIENT:
				Log.i("BaseService", "Client registered: " + msg.replyTo);
				mClients.add(msg.replyTo);
				break;
			case MSG_UNREGISTER_CLIENT:
				Log.i("BaseService", "Client un-registered: " + msg.replyTo);
				mClients.remove(msg.replyTo);
				break;
			default:
				// Pass the message on to our subclass.
				// super.handleMessage(msg);
				onReceiveMessage(msg);
			}
		}
	});

	@Override
	public void onCreate() {
		super.onCreate();

		onStartingService();

		Log.i(LOGTAG, "Service Started.");
	}

	@Override
	/**
	 * This gets called any time anyone sends us an Intent. Don't do any
	 * one-time initialization -- do that in onCreate.
	 */
	public int onStartCommand(Intent intent, int flags, int startId) {
		Log.i(LOGTAG, "Received start id " + startId + ": " + intent);
		return START_STICKY; // run until explicitly stopped.
	}

	@Override
	public IBinder onBind(Intent intent) {
		return mMessenger.getBinder();
	}

	@Override
	public void onDestroy() {
		super.onDestroy();

		onStoppingService();

		Log.i(LOGTAG, "Service Stopped.");
	}

	protected void send(Message msg) {
		for (int i = mClients.size() - 1; i >= 0; i--) {
			try {
				Log.i(LOGTAG, "Sending message to clients: " + msg);
				mClients.get(i).send(msg);
			} catch (RemoteException e) {
				// The client is dead. Remove it from the list; we are going
				// through the list from back to front so this is safe to do
				// inside the loop.
				Log.e(LOGTAG, "Client is dead. Removing from list: " + i);
				mClients.remove(i);
			}
		}
	}

	public abstract void onStartingService();

	public abstract void onStoppingService();

	public abstract void onReceiveMessage(Message msg);

}