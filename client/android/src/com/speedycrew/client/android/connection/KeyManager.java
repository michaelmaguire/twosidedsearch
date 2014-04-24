package com.speedycrew.client.android.connection;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.math.BigInteger;
import java.security.InvalidAlgorithmParameterException;
import java.security.InvalidKeyException;
import java.security.KeyManagementException;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.KeyStore.PrivateKeyEntry;
import java.security.KeyStoreException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.PublicKey;
import java.security.SignatureException;
import java.security.UnrecoverableEntryException;
import java.security.UnrecoverableKeyException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.security.spec.AlgorithmParameterSpec;
import java.security.spec.RSAKeyGenParameterSpec;
import java.util.Calendar;

import javax.net.ssl.KeyManagerFactory;
import javax.security.auth.x500.X500Principal;

import org.apache.http.conn.ssl.SSLSocketFactory;
import org.bouncycastle.cert.X509v3CertificateBuilder;
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter;
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.OperatorCreationException;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;

import android.content.Context;
import android.provider.Settings.Secure;
import android.security.KeyPairGeneratorSpec;
import android.util.Log;

import com.speedycrew.client.android.R;
import com.speedycrew.client.android.SpeedyCrewApplication;

public final class KeyManager {

	private static String LOGTAG = KeyManager.class.getName();

	private static KeyManager sInstance;
	private static String IDENTITY_KEY_NAME = "identityKey";

	private static class KeyStoreAndProviderPreference {
		final String mKeyStoreType;
		final String mProvider;

		KeyStoreAndProviderPreference(final String keyStoreType,
				final String provider) {
			mKeyStoreType = keyStoreType;
			mProvider = provider;
		}
	}

	private static final String ANDROID_KEY_STORE = "AndroidKeyStore";

	// Using "AndroidKeyStore" indicates the new AndroidKeyStoreProvider JCE
	// which uses hardware storage when possible.
	// @see
	// http://developer.android.com/about/versions/android-4.3.html#Security
	// If you use "AndroidKeyStore" for KeyStore 'type', then you should use
	// "AndroidKeyStore" as
	// KeyPairGenerator 'provider'.
	// If however, you want to use getDetaultType KeyStore type which is usually
	// 'BKS' then
	// strangely the appropriate provider type to use is 'BC'.
	private static final KeyStoreAndProviderPreference sKeyStoreAndProviderPreferences[] = {
			new KeyStoreAndProviderPreference(ANDROID_KEY_STORE,
					ANDROID_KEY_STORE),
			new KeyStoreAndProviderPreference("BKS", "BC") };

	private KeyStoreAndProviderPreference mKeyStoreToUse = sKeyStoreAndProviderPreferences[1];

	private static String ENCRYPTION_ALGORITHM_RSA = "RSA";

	private static String FINGERPRINT_ALGORITHM_SHA1 = "SHA1";

	private static final int KEY_SIZE_IN_BITS = 2048;

	private KeyStore mKeyStore;

	public static synchronized KeyManager getInstance() throws Exception {
		if (sInstance == null) {
			sInstance = new KeyManager();
		}
		return sInstance;
	}

	private KeyManager() throws Exception {
		Log.i(LOGTAG, "getPrivateKey KeyManager(): " + mKeyStoreToUse);

		try {
			if (null == getPrivateKeyEntry()) {
				initKeyStore();
			}
		} catch (Exception e) {
			Log.i(LOGTAG, "getPrivateKey KeyManager(): " + e);
			throw e;
		}
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

		String androidId = Secure.getString(context.getContentResolver(),
				Secure.ANDROID_ID);
		if (androidId == null) {
			androidId = "null_ANDROID_ID";
		}

		commonName.append(androidId);
		commonName.append("-");
		commonName.append(Long.toString(System.currentTimeMillis()));

		return commonName.toString();
	}

	/**
	 * TODO: Use the public key material in our original, generated self-signed
	 * certificate to create a CSR which we signed with our trusted root, then
	 * call this method to replace the cert entry corresponding to our private
	 * key with the signed cert.
	 * 
	 * @param trustedRootCertSignedCertificate
	 * @throws KeyStoreException
	 * @throws IOException
	 * @throws CertificateException
	 * @throws NoSuchAlgorithmException
	 */
	private void replaceSelfSignedCertificate(
			java.security.cert.X509Certificate trustedRootCertSignedCertificate)
			throws KeyStoreException, NoSuchAlgorithmException,
			CertificateException, IOException {
		mKeyStore.setCertificateEntry(IDENTITY_KEY_NAME,
				trustedRootCertSignedCertificate);
	}

	/**
	 * This method is complicated by the fact that we try to handle creation and
	 * storage of an RSA keypair in two different ways -- one is using the
	 * Android default storage type and the other is using the Android hardware
	 * keystore. Sadly, although the same information is needed for both cases,
	 * sometimes must be supplied at different stages of the creation/storage
	 * process.
	 * 
	 * 
	 * @see http 
	 *      ://nelenkov.blogspot.co.uk/2013/08/credential-storage-enhancements
	 *      -android-43.html
	 * @throws NoSuchAlgorithmException
	 * @throws NoSuchProviderException
	 * @throws InvalidAlgorithmParameterException
	 * @throws KeyStoreException
	 * @throws IOException
	 * @throws CertificateException
	 * @throws SignatureException
	 * @throws IllegalStateException
	 * @throws InvalidKeyException
	 * @throws OperatorCreationException
	 * @throws UnrecoverableEntryException
	 */
	private void initKeyStore() throws NoSuchAlgorithmException,
			NoSuchProviderException, InvalidAlgorithmParameterException,
			KeyStoreException, CertificateException, IOException,
			InvalidKeyException, IllegalStateException, SignatureException,
			OperatorCreationException, UnrecoverableEntryException {
		Context context = SpeedyCrewApplication.getAppContext();

		mKeyStore = KeyStore.getInstance(mKeyStoreToUse.mKeyStoreType);

		try {
			if (ANDROID_KEY_STORE.equals(mKeyStoreToUse.mKeyStoreType)) {
				mKeyStore.load(null);
			} else {
				FileInputStream fis = null;
				try {
					fis = context.openFileInput("identity.keystore");
					mKeyStore.load(fis,
							"dummy1234trustinginmodeprivate".toCharArray());
				} catch (FileNotFoundException fnfe) {
					// We're starting from scratch, we'll create new key below.
					// Ensure KeyStore is initialized.
					mKeyStore.load(null);
				} finally {
					if (null != fis) {
						fis.close();
					}
				}
			}
		} catch (Exception e) {
			Log.i(LOGTAG, "initKeyStore load exception, will try to create: "
					+ e.getMessage());
		}

		// See if we already have a key available, otherwise generate.
		if (null == getPrivateKeyEntry()) {

			String commonName = generateCommonName(context);

			// Note: We SHOULD NOT attempt to use certificate serial numbers to
			// track users -- we have no control over certificate creation, so
			// we
			// have no way of guaranteeing uniqueness of serial numbers. We
			// SHOULD
			// instead use public key fingerprints as a unique handle on users.
			BigInteger serialNumber = BigInteger.valueOf(System
					.currentTimeMillis());

			X500Principal subject = new X500Principal(String.format(
					"CN=%s,OU=%s", commonName, context.getPackageName()));

			Calendar notBefore = Calendar.getInstance();
			Calendar notAfter = Calendar.getInstance();
			notAfter.add(1, Calendar.YEAR);

			AlgorithmParameterSpec spec = null;
			if (ANDROID_KEY_STORE.equals(mKeyStoreToUse.mKeyStoreType)) {
				spec = new KeyPairGeneratorSpec.Builder(context)
						.setAlias(IDENTITY_KEY_NAME).setSubject(subject)
						.setSerialNumber(serialNumber)
						.setStartDate(notBefore.getTime())
						.setEndDate(notAfter.getTime()).build();
			} else {
				spec = new RSAKeyGenParameterSpec(KEY_SIZE_IN_BITS,
						RSAKeyGenParameterSpec.F4);
			}

			// If 2nd parameter provider here is "AndroidKeyStore" it indicates
			// the
			// new AndroidKeyStoreProvider JCE which uses hardware storage when
			// possible.
			KeyPairGenerator kpGenerator = KeyPairGenerator.getInstance(
					ENCRYPTION_ALGORITHM_RSA, mKeyStoreToUse.mProvider);
			kpGenerator.initialize(spec);

			KeyPair keyPair = kpGenerator.generateKeyPair();
			if (ANDROID_KEY_STORE.equals(mKeyStoreToUse.mKeyStoreType)) {
				// No need to store -- it will be stored for us in hardware.
			} else {
				ContentSigner sigGen = new JcaContentSignerBuilder(
						"SHA256WithRSAEncryption").setProvider(
						mKeyStoreToUse.mProvider).build(keyPair.getPrivate());
				X509v3CertificateBuilder certGen = new JcaX509v3CertificateBuilder(
						subject, serialNumber, notBefore.getTime(),
						notAfter.getTime(), subject, keyPair.getPublic());

				X509Certificate cert = new JcaX509CertificateConverter()
						.setProvider(mKeyStoreToUse.mProvider).getCertificate(
								certGen.build(sigGen));

				Certificate[] certChain = { cert };
				KeyStore.PrivateKeyEntry privateKeyEntry = new KeyStore.PrivateKeyEntry(
						keyPair.getPrivate(), certChain);
				mKeyStore.setEntry(IDENTITY_KEY_NAME, privateKeyEntry, null);

				// Test fetch.
				KeyStore.PrivateKeyEntry keyEntry = (KeyStore.PrivateKeyEntry) mKeyStore
						.getEntry(IDENTITY_KEY_NAME, null);

				Certificate certTest = keyEntry.getCertificate();

				System.out.println(certTest.toString());

				FileOutputStream fos = null;
				try {
					fos = context.openFileOutput("identity.keystore",
							Context.MODE_PRIVATE);
					mKeyStore.store(fos,
							"dummy1234trustinginmodeprivate".toCharArray());
				} finally {
					if (null != fos) {
						fos.close();
					}
				}

			}

			// TODO: Fetch the public key from the generated pair, turn it into
			// a
			// CSR, and obtain a certificate over the public key signed signed
			// by a
			// trusted root, then call replaceSelfSignedCertificate().
			PublicKey publicKey = keyPair.getPublic();

			// Need spongycastle, or is there a way to do this in Android
			// already?
			// We examples use com.sun.security.pkcs.PKCS10, which isn't
			// available
			// on Android.
			// PKCS10CertificationRequest request = new
			// PKCS10CertificationRequest();
		}

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
	PrivateKeyEntry getPrivateKeyEntry() throws NoSuchAlgorithmException,
			UnrecoverableEntryException, KeyStoreException,
			CertificateException, IOException {

		try {
			KeyStore.PrivateKeyEntry keyEntry = (KeyStore.PrivateKeyEntry) mKeyStore
					.getEntry(IDENTITY_KEY_NAME, null);
			return keyEntry;
		} catch (Exception e) {
			Log.i(LOGTAG, "getPrivateKey exception: " + e.getMessage());
			return null;
		}
	}

	/**
	 * This is the hex-encoded SHA1 hash of the public key. It's the best thing
	 * to use as a unique identifying ID for a user.
	 * 
	 * @throws IOException
	 * @throws CertificateException
	 * @throws KeyStoreException
	 * @throws UnrecoverableEntryException
	 * @throws NoSuchAlgorithmException
	 */
	public String getUserId() throws NoSuchAlgorithmException,
			UnrecoverableEntryException, KeyStoreException,
			CertificateException, IOException {
		PrivateKeyEntry privateKeyEntry = getPrivateKeyEntry();

		X509Certificate certificate = (X509Certificate) privateKeyEntry
				.getCertificate();

		return getPublicKeySHA1Fingerprint(certificate);
	}

	/**
	 * Given an X509 certificate returns the standard SHA1 fingerprint of ONLY
	 * ITS PUBLIC KEY.
	 * 
	 * TODO: Should we instead do a SHA1 hash of the whole encoded certificate?
	 * There doesn't seem to be too much a of standard for this.
	 * 
	 * @param certificate
	 * @return
	 * @throws NoSuchAlgorithmException
	 */
	public static String getPublicKeySHA1Fingerprint(
			java.security.cert.X509Certificate certificate)
			throws NoSuchAlgorithmException {

		MessageDigest md = MessageDigest
				.getInstance(FINGERPRINT_ALGORITHM_SHA1);
		byte[] asn1EncodedPublicKey = md.digest(certificate.getPublicKey()
				.getEncoded());

		// Hex encode.
		StringBuffer hexString = new StringBuffer();
		for (int i = 0; i < asn1EncodedPublicKey.length; i++) {
			String appendString = Integer
					.toHexString(0xFF & asn1EncodedPublicKey[i]);
			// Left pad with zero if necessary.
			if (appendString.length() == 1) {
				hexString.append("0");
			}
			hexString.append(appendString);
		}
		return hexString.toString();
	}

	public SSLSocketFactory getSSLSocketFactory() throws KeyStoreException,
			NoSuchAlgorithmException, UnrecoverableKeyException,
			CertificateException, IOException, KeyManagementException,
			Exception {

		try {

			Context context = SpeedyCrewApplication.getAppContext();

			// Initialize key manager factory with the client certificate.
			KeyManagerFactory clientKeyManagerFactory = null;
			clientKeyManagerFactory = KeyManagerFactory
					.getInstance(KeyManagerFactory.getDefaultAlgorithm());
			clientKeyManagerFactory.init(mKeyStore, "MyPassword".toCharArray());

			// Read in the root CA certs for speedycrew.com which we'll trust
			// from
			// the server.
			KeyStore localTrustStore = KeyStore.getInstance("BKS");
			InputStream in = context.getResources().openRawResource(
					R.raw.mytruststore);
			localTrustStore.load(in, "secret".toCharArray());

			// initialize SSLSocketFactory to use the certificates
			SSLSocketFactory socketFactory = null;
			socketFactory = new SSLSocketFactory(SSLSocketFactory.TLS,
					mKeyStore, null, localTrustStore, null, null);
			return socketFactory;
		} catch (Exception e) {
			Log.e(LOGTAG, "getSSLSocketFactory exception: " + e.getMessage());
			throw e;
		}
	}
}
