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

echo "❶ Step 1: Initialize variables"

# Interactive input for custom variables
read -r -p "Enter the Common Name (CN) [default: example.com.tw]: " CNAME
CNAME=${CNAME:-example.com.tw}

# SAN (Subject Alternative Name) is used to specify additional host names for a certificate
read -r -p "Enter the Subject Alternative Name (SAN) (comma-separated) [default: DNS:kafka-1,DNS:kafka-2,DNS:localhost]: " SAN
SAN=${SAN:-DNS:kafka-1,DNS:kafka-2,DNS:localhost}

read -r -p "Enter the Organizational Unit (OU) [default: IT Department]: " ORG_UNIT
ORG_UNIT=${ORG_UNIT:-IT Department}

read -r -p "Enter the Organization Name (O) [default: Example]: " ORG_NAME
ORG_NAME=${ORG_NAME:-Example}

read -r -p "Enter the Locality (L) [default: Taipei]: " LOCALITY
LOCALITY=${LOCALITY:-Taipei}

read -r -p "Enter the State or Province (ST) [default: Taiwan]: " STATE_OR_PROVINCE
STATE_OR_PROVINCE=${STATE_OR_PROVINCE:-Taiwan}

read -r -p "Enter the Country Code (C) [default: TW]: " COUNTRY_CODE
COUNTRY_CODE=${COUNTRY_CODE:-TW}

read -r -p "Enter the password for the certificates [default: 123456]: " PASSWORD
PASSWORD=${PASSWORD:-123456}

read -r -p "Enter the number of days the certificate is valid for [default: 365]: " DAYS_VALID
DAYS_VALID=${DAYS_VALID:-365}

# Pre-defined variables
CERT_OUTPUT_PATH="$PWD/certs"
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
echo "CERTS_STORE_PASSWORD=$STORE_PASSWORD" > .env
echo "CERTS_TRUSTSTORE_PASSWORD=$TRUST_STORE_PASSWORD" >> .env
echo "Environment file generated: (.env)"

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