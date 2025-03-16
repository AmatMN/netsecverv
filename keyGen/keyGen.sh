#!/bin/bash

V3_EXT_PATH="./v3.ext"
NGINX_V3_EXT_PATH="./nginx.v3.ext"

CA_KEY="ca.key"
CA_CRT="ca.crt"

SERVER_KEY="server.key"
SERVER_CSR="server.csr"
SERVER_CRT="server.crt"

NGINX_KEY="nginx.key"
NGINX_CSR="nginx.csr"
NGINX_CRT="nginx.crt"

# Check if required files exist
if [[ ! -f "$V3_EXT_PATH" || ! -f "$NGINX_V3_EXT_PATH" ]]; then
    echo "Error: One or more required files (v3.ext and/or nginx.v3.ext) not found!"
    exit 1
fi

# Generate CA key and certificate
openssl genrsa -out $CA_KEY 2048
openssl req -new -x509 -days 1826 -key $CA_KEY -out $CA_CRT -subj "/C=NL/ST=Zuid-Holland/L=Rotterdam/O=HR/OU=TINNES01/CN=ca-0978246"

# Extract domain from v3.ext
DOMAIN=$(grep -Po '(?<=IP\.1 = )[^ ]+' "$NGINX_V3_EXT_PATH")
if [[ -z "$DOMAIN" ]]; then
    echo "Error: Could not extract IP from $V3_EXT_PATH"
    exit 1
fi
echo "Using domain: $DOMAIN"

# Generate server key and certificate
openssl genrsa -out $SERVER_KEY 2048
openssl req -new -key $SERVER_KEY -out $SERVER_CSR -subj "/C=NL/ST=Zuid-Holland/L=Rotterdam/O=HR/OU=TINNES01/CN=$DOMAIN"
openssl x509 -req -in $SERVER_CSR -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out $SERVER_CRT -days 365 -sha256 -extfile "$V3_EXT_PATH"

# Extract domain for NGINX
DOMAIN2=$(grep -Po '(?<=DNS\.1 = )[^ ]+' "$NGINX_V3_EXT_PATH")
if [[ -z "$DOMAIN2" ]]; then
    echo "Error: Could not extract DNS from $NGINX_V3_EXT_PATH"
    exit 1
fi
echo "Using domain: $DOMAIN2"

# Generate NGINX key and certificate
openssl genrsa -out $NGINX_KEY 2048
openssl req -new -key $NGINX_KEY -out $NGINX_CSR -subj "/C=NL/ST=Zuid-Holland/L=Rotterdam/O=HR/OU=TINNES01/CN=$DOMAIN2"
openssl x509 -req -in $NGINX_CSR -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out $NGINX_CRT -days 365 -sha256 -extfile "$NGINX_V3_EXT_PATH"

# Verify generated files exist
for file in $SERVER_CRT $SERVER_KEY $SERVER_CSR $CA_CRT $CA_KEY $NGINX_CRT $NGINX_KEY $NGINX_CSR; do
    if [[ ! -f "$file" ]]; then
        echo "Error: Expected file $file not found!"
        exit 1
    fi

done

# set permissions, owners and locations

chmod 644 ./*.crt ./*.csr ./*.srl
chmod 600 ./*.key
chown 1883:1883 -R ./*.key ./*.crt ./*.csr ./*.srl
chown www-data:www-data ./ca.key

mkdir -p "../certificates/ca"
mkdir -p "../certificates/broker"
mkdir -p "../certificates/ssl"

mv ./ca.* "../certificates/ca"
mv ./nginx.* "../certificates/ssl"
mv ./server.* "../certificates/broker"

echo "Certificates securely stored."