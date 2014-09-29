# IOS Client for SpeedyCrew

## Building the IOS Client

The client requires a few submodules:

1. SDWebImage to deal with loading images from URLs
2. ios-openssl to have fixed version of openssl

## Client Certs

work items:

 1. Integrate a newer version of openssl (libssl and libcrypto)
 2. Generate a 2048 bit RSA public/private keypair.
 3. Create the self-signed X509 cert over the public key.
 4. Use it in the SSL connection yet.

## Useful Server commands:

 1. @tsuru: psql speedycrew_dev speedycrew
    select * from <press-tab>
 2. sudo less /var/log/apache2/other_vhosts_access.log
