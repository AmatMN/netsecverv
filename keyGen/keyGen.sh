#!/bin/bash

V3_EXT_PATH="./v3.ext"
NGINX_V3_EXT_PATH="./nginx.v3.ext"

CA_KEY="ca.key"
CA_KEY_PATH="../broker/all_certs/"
CA_CRT="ca.crt"
CA_CRT_PATH="../broker/ca_certificates/"
CA_SRL_PATH="./ca.srl"

# Set filenames for generated files
SERVER_KEY="server.key"
SERVER_CSR="server.csr"
SERVER_CRT="server.crt"
SERVER_CERT_PATH="../broker/certs/"

NGINX_KEY="nginx.key"
NGINX_CSR="nginx.csr"
NGINX_CRT="nginx.crt"
NGINX_CERT_PATH="../client/certs/ssl_certs/"

# Check if required files exist
if [[ ! -f "$V3_EXT_PATH" || ! -f "$NGINX_V3_EXT_PATH" ]]; then
    echo "Error: One or more required files (v3.ext and/or nginx.v3.ext) not found!"
    exit 1
fi

openssl genrsa -out $CA_KEY 2048

openssl req -new -x509 -days 1826 -key $CA_KEY -out $CA_CRT -subj "/C=NL/ST=0978246/L=0978246/O=0978246/OU=0978246/CN=0978246"

# Extract DNS.1 or fallback to IP.1 from v3.ext
DOMAIN=$(grep -Po '(?<=DNS\.1 = )[^ ]+' "$V3_EXT_PATH")
if [[ -z "$DOMAIN" ]]; then
    DOMAIN=$(grep -Po '(?<=IP\.1 = )[^ ]+' "$V3_EXT_PATH")
fi

# Validate DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo "Error: Could not extract DNS from $V3_EXT_PATH"
    exit 1
fi

echo "Using domain: $DOMAIN"

# Generate server private key
openssl genrsa -out $SERVER_KEY 2048

# Create a certificate signing request (CSR)
openssl req -new -key $SERVER_KEY -out $SERVER_CSR -subj "/C=NL/ST=0978246/L=0978246/O=0978246/OU=0978246/CN=$DOMAIN"

# Generate server certificate signed by CA (bypassing password prompt)
openssl x509 -req -in $SERVER_CSR -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out $SERVER_CRT -days 365 -sha256 -extfile "$V3_EXT_PATH"

echo "Server certificate generated successfully using $DOMAIN."

# Ensure destination directory exists
mkdir -p "$SERVER_CERT_PATH"

# Move generated files to the destination directory
mv $SERVER_KEY $SERVER_CSR $SERVER_CRT "$SERVER_CERT_PATH"

echo "Files moved to $SERVER_CERT_PATH."


# now repeat but for https certs


# Extract DNS.1 or fallback to IP.1 from v3.ext
DOMAIN=$(grep -Po '(?<=DNS\.1 = )[^ ]+' "$V3_EXT_PATH")
if [[ -z "$DOMAIN" ]]; then
    DOMAIN=$(grep -Po '(?<=IP\.1 = )[^ ]+' "$V3_EXT_PATH")
fi

# Validate DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo "Error: Could not extract DNS from $NGINX_V3_EXT_PATH"
    exit 1
fi

echo "Using domain: $DOMAIN"

# Generate NGINX private key
openssl genrsa -out $NGINX_KEY 2048

# Create a certificate signing request (CSR)
openssl req -new -key $NGINX_KEY -out $NGINX_CSR -subj "/C=NL/ST=0978246/L=0978246/O=0978246/OU=0978246/CN=$DOMAIN"

# Generate NGINX certificate signed by CA (bypassing password prompt)
openssl x509 -req -in $NGINX_CSR -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out $NGINX_CRT -days 365 -sha256 -extfile "$NGINX_V3_EXT_PATH"

echo "NGINX certificate generated successfully using $DOMAIN."

# Ensure destination directory exists
mkdir -p "$NGINX_CERT_PATH"

# Move generated files to the destination directory
mv $NGINX_KEY $NGINX_CSR $NGINX_CRT "$NGINX_CERT_PATH"

echo "Files moved to $NGINX_CERT_PATH."

# Ensure destination directory exists
mkdir -p "$CA_KEY_PATH"

# Move generated files to the destination directory
mv $CA_KEY "$CA_KEY_PATH"

# Ensure destination directory exists
mkdir -p "$CA_CRT_PATH"

# Move generated files to the destination directory
mv $CA_CRT $CA_SRL_PATH "$CA_CRT_PATH"

echo "Files moved to $CA_CRT_PATH and $CA_KEY_PATH."