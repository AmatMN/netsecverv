#!/bin/bash

docker-compose down

# Ask for the domain
read -p "Enter the domain name (e.g., example.com or 'localhost'): " DOMAIN

# If localhost, no need for a subdomain
if [[ "$DOMAIN" == "localhost" ]]; then
    FULL_DOMAIN="localhost"
    USE_LOCAL_ONLY=true
else
    read -p "Enter a subdomain (or leave blank for none): " SUBDOMAIN
    if [[ -n "$SUBDOMAIN" ]]; then
        FULL_DOMAIN="$SUBDOMAIN.$DOMAIN"
    else
        FULL_DOMAIN="$DOMAIN"
    fi
    USE_LOCAL_ONLY=false
fi

# Get the local and external IP addresses
LOCAL_IP=$(hostname -I | awk '{print $1}')
EXTERNAL_IP=$(curl -s https://api64.ipify.org)

# If using localhost, set external IP to local IP
if [[ "$USE_LOCAL_ONLY" == true ]]; then
    EXTERNAL_IP="$LOCAL_IP"
fi

echo "Local IP: $LOCAL_IP"
echo "External IP: $EXTERNAL_IP"

# Define the .ext file paths
EXT_FILE1="./keyGen/v3.ext"
EXT_FILE2="./keyGen/nginx.v3.ext"

# Update first .ext file
if [[ -f "$EXT_FILE1" ]]; then
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$EXT_FILE1"
    sed -i "s/STAR_/*./g" "$EXT_FILE1"
    echo "Updated $EXT_FILE1 with domain and wildcard."
else
    echo "Error: File $EXT_FILE1 not found!"
    exit 1
fi

# Update second .ext file
if [[ -f "$EXT_FILE2" ]]; then
    sed -i "s/FULL_DOMAIN_PLACEHOLDER/$FULL_DOMAIN/g" "$EXT_FILE2"
    sed -i "s/STAR_/*./g" "$EXT_FILE2"
    sed -i "s/EXTERNAL_IP_PLACEHOLDER/$EXTERNAL_IP/g" "$EXT_FILE2"
    sed -i "s/LOCAL_IP_PLACEHOLDER/$LOCAL_IP/g" "$EXT_FILE2"
    echo "Updated $EXT_FILE2 with full domain, wildcard, and IPs."
else
    echo "Error: File $EXT_FILE2 not found!"
    exit 1
fi

# Run the certificate generation script
echo "Generating SSL certificates..."
cd ./keyGen || { echo "Error: keyGen directory not found!"; exit 1; }
./keyGen.sh
cd - || exit 1

# Start the Docker containers
echo "Starting Docker containers..."
docker-compose up -d

chown www-data:www-data ./certificates/ca/ca.key
chown www-data:www-data ./certificates/ssl/nginx.key
chown www-data:www-data ./certificates/ca/intermediate.key

echo "Setup complete!"
