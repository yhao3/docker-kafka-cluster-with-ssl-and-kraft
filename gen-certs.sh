#!/bin/bash

# Check Keytool and OpenSSL...
if ! command -v keytool &> /dev/null; then
  echo "keytool could not be found"
  exit 1
fi
echo "✅ Keytool found!"

if ! command -v openssl &> /dev/null; then
  echo "openssl could not be found"
  exit 1
fi
echo "✅ OpenSSL found!"

echo "Update OpenSSL..."
apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
echo "✅ OpenSSL updated!"

echo "❶ Step 1: Initialize variables"

CNAME=${CNAME:-example.com.tw}
SAN=${SAN:-DNS:kafka-1,DNS:kafka-2,DNS:localhost}
ORG_UNIT=${ORG_UNIT:-IT Department}
ORG_NAME=${ORG_NAME:-Example}
LOCALITY=${LOCALITY:-Taipei}
STATE_OR_PROVINCE=${STATE_OR_PROVINCE:-Taiwan}
COUNTRY_CODE=${COUNTRY_CODE:-TW}
PASSWORD=${PASSWORD:-123456}
DAYS_VALID=${DAYS_VALID:-365}

# Pre-defined variables
CERT_OUTPUT_PATH="/certs"
KEY_STORE="$CERT_OUTPUT_PATH/kafka.keystore.jks"
TRUST_STORE="$CERT_OUTPUT_PATH/kafka.truststore.jks"
KEY_PASSWORD=$PASSWORD
STORE_PASSWORD=$PASSWORD
TRUST_STORE_PASSWORD=$PASSWORD
CLUSTER_NAME=kafka-cluster
CERT_AUTH_FILE="$CERT_OUTPUT_PATH/ca-cert"
CLUSTER_CERT_FILE="$CERT_OUTPUT_PATH/${CLUSTER_NAME}-cert"
D_NAME="CN=$CNAME, OU=$ORG_UNIT, O=$ORG_NAME, L=$LOCALITY, ST=$STATE_OR_PROVINCE, C=$COUNTRY_CODE"

# Create output directory
# If the directory exists and is not empty, exit
if [ -d "$CERT_OUTPUT_PATH" ] && [ "$(ls -A "$CERT_OUTPUT_PATH")" ]; then
  echo "Directory ($CERT_OUTPUT_PATH) already exists and is not empty. Please remove the directory or specify another directory."
  exit 1
fi
mkdir -p "$CERT_OUTPUT_PATH"
echo "Directory ($CERT_OUTPUT_PATH) created!"

echo "Generate credentials for Kafka..."
echo "$STORE_PASSWORD" > "$CERT_OUTPUT_PATH"/kafka_keystore_creds
echo "$TRUST_STORE_PASSWORD" > "$CERT_OUTPUT_PATH"/kafka_truststore_creds
echo "$KEY_PASSWORD" > "$CERT_OUTPUT_PATH"/kafka_ssl_key_creds
echo "Credentials generated: $CERT_OUTPUT_PATH/kafka_keystore_creds, $CERT_OUTPUT_PATH/kafka_truststore_creds, $CERT_OUTPUT_PATH/kafka_ssl_key_creds"

echo "Generate .env file..."
echo "KAFKA_CLUSTERS_0_PROPERTIES_SSL_KEYSTORE_PASSWORD=$STORE_PASSWORD" > /config/.env
echo "KAFKA_CLUSTERS_0_SSL_TRUSTSTOREPASSWORD=$TRUST_STORE_PASSWORD" >> /config/.env
echo "Environment file generated: (/config/.env)"

echo "❷ Step 2: Create CA"
openssl req -new -x509 \
  -keyout "$CERT_OUTPUT_PATH"/ca-key \
  -out "$CERT_AUTH_FILE" \
  -days "$DAYS_VALID" \
  -passin pass:"$PASSWORD" \
  -passout pass:"$PASSWORD" \
  -subj "/C=$COUNTRY_CODE/ST=$STATE_OR_PROVINCE/L=$LOCALITY/O=$ORG_NAME/CN=$CNAME"

echo "❸ Step 3: Import CA into truststore"
keytool -keystore "$TRUST_STORE" \
  -alias CARoot \
  -import \
  -file "$CERT_AUTH_FILE" \
  -storepass "$TRUST_STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -noprompt

echo "❹ Step 4: Create keystore and generate key pair"
keytool -keystore "$KEY_STORE" \
  -alias $CLUSTER_NAME \
  -validity "$DAYS_VALID" \
  -genkey \
  -keyalg RSA \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -dname "$D_NAME" \
  -ext "SAN=$SAN"

echo "❺ Step 5: Create certificate signing request (CSR)"
keytool -keystore "$KEY_STORE" \
  -alias "$CLUSTER_NAME" \
  -certreq \
  -file "$CLUSTER_CERT_FILE" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -ext "SAN=$SAN"

echo "❻ Step 6: Sign the certificate"
openssl x509 -req \
  -CA "$CERT_AUTH_FILE" \
  -CAkey "$CERT_OUTPUT_PATH"/ca-key \
  -in "$CLUSTER_CERT_FILE" \
  -out "${CLUSTER_CERT_FILE}-signed" \
  -days "$DAYS_VALID" \
  -CAcreateserial \
  -passin pass:"$PASSWORD" \
  -extensions v3_req \
  -extfile <(printf "[v3_req]\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth,clientAuth\nsubjectAltName=$SAN")

echo "❼ Step 7: Import CA into keystore"
keytool -keystore "$KEY_STORE" \
  -alias CARoot \
  -import \
  -file "$CERT_AUTH_FILE" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -noprompt

echo "❽ Step 8: Import signed certificate into keystore"
keytool -keystore "$KEY_STORE" \
  -alias "${CLUSTER_NAME}" \
  -import \
  -file "${CLUSTER_CERT_FILE}-signed" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -noprompt

echo "🎉 Successfully generated certificates for Kafka!"

exit 0