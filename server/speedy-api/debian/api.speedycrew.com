<VirtualHost *:443>
    ServerName api.speedycrew.com
    WSGIScriptAlias / /usr/lib/speedy-api/speedy-api.wsgi
    SSLEngine on
    SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
    SSLVerifyClient optional_no_ca
    SSLOptions +StdEnvVars +ExportCertData
</VirtualHost>
