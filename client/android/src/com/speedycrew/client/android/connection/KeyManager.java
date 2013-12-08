package com.speedycrew.client.android.connection;

import java.io.IOException;
import java.io.StringWriter;
import java.math.BigInteger;
import java.security.InvalidAlgorithmParameterException;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.KeyStore.PrivateKeyEntry;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.UnrecoverableEntryException;
import java.security.cert.CertificateException;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.util.Calendar;

import javax.security.auth.x500.X500Principal;

import android.content.Context;
import android.provider.Settings.Secure;
import android.security.KeyPairGeneratorSpec;

import com.speedycrew.client.android.SpeedyCrewApplication;

public class KeyManager {

	private static KeyManager sInstance;
	private static String IDENTITY_KEY_NAME = "identityKey";

	// Using "AndroidKeyStore" indicates the new AndroidKeyStoreProvider JCE
	// which uses hardware storage when possible.
	// @see
	// http://developer.android.com/about/versions/android-4.3.html#Security
	private static String ANDROID_KEY_STORE = "AndroidKeyStore";

	private static String ENCRYPTION_ALGORITHM_RSA = "RSA";

	public static synchronized KeyManager getInstance() throws NoSuchAlgorithmException, NoSuchProviderException, InvalidAlgorithmParameterException {
		if (sInstance == null) {
			sInstance = new KeyManager();
		}
		return sInstance;
	}

	private KeyManager() throws NoSuchAlgorithmException, NoSuchProviderException, InvalidAlgorithmParameterException {
		initKey();
	}

	/**
	 * We'd like something mildly unique to use as the CommonName attribute in
	 * our certificate's subject name. ANDROID_ID has some well-known issues,
	 * but should be fine.
	 * 
	 * Note: Certificate CN SHOULDN NOT be used for anything essential in our
	 * infrastructure -- identifying users should be based on (the hash
	 * fingerprint) of their public key.
	 * 
	 * @see http
	 *      ://stackoverflow.com/questions/2785485/is-there-a-unique-android-
	 *      device-id
	 */
	private static String generateCommonName(Context context) {
		StringWriter commonName = new StringWriter();

		String androidId = Secure.getString(context.getContentResolver(), Secure.ANDROID_ID);
		if (androidId == null) {
			androidId = "null_ANDROID_ID";
		}

		commonName.append(androidId);
		commonName.append("-");
		commonName.append(Long.toString(System.currentTimeMillis()));

		return commonName.toString();
	}

	/**
	 * @see http 
	 *      ://nelenkov.blogspot.co.uk/2013/08/credential-storage-enhancements
	 *      -android-43.html
	 * @throws NoSuchAlgorithmException
	 * @throws NoSuchProviderException
	 * @throws InvalidAlgorithmParameterException
	 */

	private void initKey() throws NoSuchAlgorithmException, NoSuchProviderException, InvalidAlgorithmParameterException {
		Context context = SpeedyCrewApplication.getAppContext();

		String commonName = generateCommonName(context);

		// Note: We SHOULD NOT attempt to use certificate serial numbers to
		// track users -- we have no control over certificate creation, so we
		// have no way of guaranteeing uniqueness of serial numbers. We SHOULD
		// instead use public key fingerprints as a unique handle on users.
		BigInteger serialNumber = BigInteger.valueOf(System.currentTimeMillis());

		X500Principal subject = new X500Principal(String.format("CN=%s,OU=%s", commonName, context.getPackageName()));

		Calendar notBefore = Calendar.getInstance();
		Calendar notAfter = Calendar.getInstance();
		notAfter.add(1, Calendar.YEAR);
		KeyPairGeneratorSpec spec = new KeyPairGeneratorSpec.Builder(context).setAlias(IDENTITY_KEY_NAME).setSubject(subject).setSerialNumber(serialNumber)
				.setStartDate(notBefore.getTime()).setEndDate(notAfter.getTime()).build();

		// 2nd parameter "AndroidKeyStore" provider here indicates the new
		// AndroidKeyStoreProvider JCE which uses hardware storage when
		// possible.
		KeyPairGenerator kpGenerator = KeyPairGenerator.getInstance(ENCRYPTION_ALGORITHM_RSA, ANDROID_KEY_STORE);
		kpGenerator.initialize(spec);

		// No need to store -- it will be stored for us in hardware.
		/* KeyPair kp = */kpGenerator.generateKeyPair();
	}

	/**
	 * Can use: RSAPublicKey pubKey =
	 * (RSAPublicKey)keyEntry.getCertificate().getPublicKey(); RSAPrivateKey
	 * privKey = (RSAPrivateKey) keyEntry.getPrivateKey();
	 * 
	 * @return
	 * @throws NoSuchAlgorithmException
	 * @throws UnrecoverableEntryException
	 * @throws KeyStoreException
	 * @throws CertificateException
	 * @throws IOException
	 */
	PrivateKeyEntry getPrivateKeyEntry() throws NoSuchAlgorithmException, UnrecoverableEntryException, KeyStoreException, CertificateException, IOException {
		KeyStore keyStore = KeyStore.getInstance(ANDROID_KEY_STORE);
		keyStore.load(null);
		KeyStore.PrivateKeyEntry keyEntry = (KeyStore.PrivateKeyEntry) keyStore.getEntry(IDENTITY_KEY_NAME, null);
		return keyEntry;
	}

}
