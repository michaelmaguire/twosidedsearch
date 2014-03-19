package com.speedycrew.client.util;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;

public class ServiceConnector {

	private static String LOGTAG = ServiceConnector.class.getName();

	private Class<? extends BaseService> mServiceClass;
	private Context mContext;
	private boolean mIsBound;
	private Messenger mService;
	private final Messenger mServiceRegistrationMessenger = new Messenger(new Handler() {
		@Override
		public void handleMessage(Message msg) {
			Log.i(LOGTAG, "handleMessage: " + msg);
		}
	});

	private ServiceConnection mConnection = new ServiceConnection() {
		public void onServiceConnected(ComponentName className, IBinder service) {
			mService = new Messenger(service);
			// textStatus.setText("Attached.");
			Log.i(LOGTAG, "onServiceConnected");
			try {
				Message msg = Message.obtain(null, BaseService.MSG_REGISTER_CLIENT);
				msg.replyTo = mServiceRegistrationMessenger;
				mService.send(msg);
			} catch (RemoteException e) {
				Log.e("ServiceConnector", "onServiceConnected - the service has crashed before we could even do anything with it");
			}
		}

		public void onServiceDisconnected(ComponentName className) {
			// This is called when the connection with the service has been
			// unexpectedly disconnected - process crashed.
			mService = null;
			Log.e("ServiceConnector", "Disconnected.");
		}
	};

	public ServiceConnector(Context context, Class<? extends BaseService> serviceClass) {
		this.mContext = context;
		this.mServiceClass = serviceClass;

		doBindService();
	}

	public void start() {
		doStartService();
		doBindService();
	}

	public void stop() {
		doUnbindService();
		doStopService();
	}

	/**
	 * Use with caution (only in Activity.onDestroy())!
	 */
	public void unbind() {
		doUnbindService();
	}

	public void send(Message msg, Messenger replyTo) throws RemoteException {
		if (mIsBound) {
			if (mService != null) {
				msg.replyTo = replyTo;
				msg.arg2 = msg.hashCode();
				mService.send(msg);
			}
		}
	}

	private void doStartService() {
		mContext.startService(new Intent(mContext, mServiceClass));
	}

	private void doStopService() {
		mContext.stopService(new Intent(mContext, mServiceClass));
	}

	private void doBindService() {
		mContext.bindService(new Intent(mContext, mServiceClass), mConnection, Context.BIND_AUTO_CREATE);
		mIsBound = true;
	}

	private void doUnbindService() {
		if (mIsBound) {
			// If we have received the service, and hence registered with it,
			// then now is the time to unregister.
			if (mService != null) {
				try {
					Message msg = Message.obtain(null, BaseService.MSG_UNREGISTER_CLIENT);
					msg.replyTo = mServiceRegistrationMessenger;
					mService.send(msg);
				} catch (RemoteException e) {
					// There is nothing special we need to do if the service has
					// crashed.
				}
			}

			// Detach our existing connection.
			mContext.unbindService(mConnection);
			mIsBound = false;
			Log.i(LOGTAG, "Unbinding.");
		}
	}
}