#!/bin/bash

V3_EXT_PATH="./v3.ext"
NGINX_V3_EXT_PATH="./nginx.v3.ext"

CA_KEY="ca.key"
CA_CRT="ca.crt"
CA_SRL="ca.srl"

INTERMEDIATE_KEY="intermediate.key"
INTERMEDIATE_CSR="intermediate.csr"
INTERMEDIATE_CRT="intermediate.crt"
INTERMEDIATE_SRL="intermediate.srl"

SERVER_KEY="server.key"
SERVER_CSR="server.csr"
SERVER_CRT="server.crt"

NGINX_KEY="nginx.key"
NGINX_CSR="nginx.csr"
NGINX_CRT="nginx.crt"

CA_PASSPHRASE="yivYv98s"

# Check if required files exist
if [[ ! -f "$V3_EXT_PATH" || ! -f "$NGINX_V3_EXT_PATH" ]]; then
    echo "Error: One or more required files (v3.ext and/or nginx.v3.ext) not found!"
    exit 1
fi

openssl genrsa -des3 -passout pass:$CA_PASSPHRASE -out $CA_KEY 2048
openssl req -new -x509 -days 1826 -key $CA_KEY -passin pass:$CA_PASSPHRASE -out $CA_CRT -subj "/C=NL/ST=Zuid-Holland/L=Rotterdam/O=HR/OU=TINNES02/CN=ca-0978246/emailAddress=0978246@hr.nl"

openssl genrsa -out $INTERMEDIATE_KEY 2048
openssl req -new -key $INTERMEDIATE_KEY -out $INTERMEDIATE_CSR -subj "/C=NL/ST=Zuid-Holland/L=Rotterdam/O=HR/OU=TINNES02/CN=intermediate-ca-0978246/emailAddress=0978246@hr.nl"
openssl x509 -req -in $INTERMEDIATE_CSR -CA $CA_CRT -CAkey $CA_KEY -passin pass:$CA_PASSPHRASE -CAcreateserial -out $INTERMEDIATE_CRT -days 1826

# Extract domain from v3.ext
DOMAIN=$(grep -Po '(?<=IP\.1 = )[^ ]+' "$NGINX_V3_EXT_PATH")
if [[ -z "$DOMAIN" ]]; then
    echo "Error: Could not extract IP from $V3_EXT_PATH"
    exit 1
fi
echo "Using domain: $DOMAIN"

# Generate server key and certificate
openssl genrsa -out $SERVER_KEY 2048
openssl req -new -key $SERVER_KEY -out $SERVER_CSR -subj "/C=NL/ST=Zuid-Holland/L=Rotterdam/O=HR/OU=TINNES02/CN=$DOMAIN/emailAddress=0978246@hr.nl"
openssl x509 -req -in $SERVER_CSR -CA $INTERMEDIATE_CRT -CAkey $INTERMEDIATE_KEY -passin pass:$CA_PASSPHRASE -CAcreateserial -out $SERVER_CRT -days 360 -extfile "$V3_EXT_PATH"

# Extract domain for NGINX
DOMAIN2=$(grep -Po '(?<=DNS\.1 = )[^ ]+' "$NGINX_V3_EXT_PATH")
if [[ -z "$DOMAIN2" ]]; then
    echo "Error: Could not extract DNS from $NGINX_V3_EXT_PATH"
    exit 1
fi
echo "Using domain: $DOMAIN2"

# Generate NGINX key and certificate
openssl genrsa -out $NGINX_KEY 2048
openssl req -new -key $NGINX_KEY -out $NGINX_CSR -subj "/C=NL/ST=Zuid-Holland/L=Rotterdam/O=HR/OU=TINNES02/CN=$DOMAIN2/emailAddress=0978246@hr.nl"
openssl x509 -req -in $NGINX_CSR -CA $CA_CRT -CA $INTERMEDIATE_CRT -CAkey $INTERMEDIATE_KEY -passin pass:$CA_PASSPHRASE -CAcreateserial -out $NGINX_CRT -days 360 -extfile "$NGINX_V3_EXT_PATH"

FULLCHAIN_NGINX_FILE="fullchain_nginx.crt"
cat $NGINX_CRT $INTERMEDIATE_CRT $CA_CRT> $FULLCHAIN_NGINX_FILE

FULLCHAIN_SERVER_FILE="fullchain_server.crt"
cat $SERVER_CRT $INTERMEDIATE_CRT $CA_CRT> $FULLCHAIN_SERVER_FILE

# Verify generated files exist
for file in $SERVER_CRT $SERVER_KEY $SERVER_CSR $CA_CRT $CA_KEY $INTERMEDIATE_CRT $INTERMEDIATE_KEY $NGINX_CRT $NGINX_KEY $NGINX_CSR $FULLCHAIN_NGINX_FILE $FULLCHAIN_SERVER_FILE; do
    if [[ ! -f "$file" ]]; then
        echo "Error: Expected file $file not found!"
        exit 1
    fi
done

# set permissions, owners and locations

chmod 644 ./*.crt ./*.csr ./*.srl
chmod 640 ./*.key
chown 1883:1883 -R ./*.key ./*.crt ./*.csr ./*.srl
chown www-data:www-data ./$CA_KEY
chown www-data:www-data ./$NGINX_KEY
chown www-data:www-data ./$INTERMEDIATE_KEY

mkdir -p "../certificates/ca"
mkdir -p "../certificates/broker"
mkdir -p "../certificates/ssl"

mv $CA_KEY $CA_SRL $CA_CRT $INTERMEDIATE_KEY $INTERMEDIATE_CSR $INTERMEDIATE_CRT $INTERMEDIATE_SRL "../certificates/ca"
mv $NGINX_KEY $NGINX_CSR $NGINX_CRT $FULLCHAIN_NGINX_FILE "../certificates/ssl"
mv $SERVER_KEY $SERVER_CSR $SERVER_CRT $FULLCHAIN_SERVER_FILE "../certificates/broker"

echo "Certificates securely stored."