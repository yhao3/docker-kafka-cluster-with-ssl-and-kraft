# Docker Kafka Cluster with SSL and KRaft mode

## Pre-requisites

Before you begin, ensure that you have the following installed on your system:

- **Docker**
- **Docker Compose**
- **JRE**
- **OpenSSL**

## Quick Start

### 1. Generate certifications

First, you need to generate the certificates for the Kafka cluster. You can use the `generate-certs.sh` script to generate the self-signed certificates.

```bash
./generate-certs.sh
```

Upon running the script, you will be prompted to enter various parameters for the certificate generation. Here's an example of the expected output:

```
✅ Keytool found!
✅ OpenSSL found!
❶ Step 1: Initialize variables
Enter the Common Name (CN) [default: example.com.tw]: mycompany.com.tw
Enter the Subject Alternative Name (SAN) (comma-separated) [default: DNS:kafka-1,DNS:kafka-2,DNS:localhost]: 
Enter the Organizational Unit (OU) [default: IT Department]: 
Enter the Organization Name (O) [default: Example]: My Company
Enter the Locality (L) [default: Taipei]: 
Enter the State or Province (ST) [default: Taiwan]: 
Enter the Country Code (C) [default: TW]: 
Enter the password for the certificates [default: 123456]: p@ssw0rd
Enter the number of days the certificate is valid for [default: 365]: 90
Directory (/Users/haoyang/workspace/kafka-cluster/certs) created!
Generate credentials for Kafka...
Credentials generated: /Users/haoyang/workspace/kafka-cluster/certs/kafka_keystore_creds, /Users/haoyang/workspace/kafka-cluster/certs/kafka_truststore_creds, /Users/haoyang/workspace/kafka-cluster/certs/kafka_ssl_key_creds
Generate .env file...
Environment file generated: (.env)
❷ Step 2: Create CA
...+...+.............+..+.......+........+....+...+..+...+.+.....+..........+.........+..+...+......+......+.+..............+...+...+.......+..+......+....+...+......+......+..............+.+++++++++++++++++++++++++++++++++++++++*...+.....+++++++++++++++++++++++++++++++++++++++*.......+......+......+.........+....+.....+......+.+......+.....+...+.........+.+.........+........+....+......+.....+.......+..+..........+........+...+...+......+..........+.....+.+............+......+..+.............+......+...+...+..+.............+...+.....+...............+....+...........++++++
..+.........+......+.....+....+..............+.+..+.......+..+...+++++++++++++++++++++++++++++++++++++++*............+++++++++++++++++++++++++++++++++++++++*....+.+.....+....+...+........+.+...........+.......+..+......+....+...+...........+...................+......+......+.........+..+.........+.+..+.......+.....+.+.....+...+.+........+...+.......+.................+.+..+...............+.+.........+...+...+.....+.+...+..+.+.........+...........+.......+.....+......+......+....+..............+...+...................+..............+.+...+...........+.+.....+.........+....++++++
-----
❸ Step 3: Import CA into truststore
Certificate was added to keystore
❹ Step 4: Create keystore and generate key pair
Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA) with a validity of 90 days
        for: CN=mycompany.com.tw, OU=IT Department, O=My Company, L=Taipei, ST=Taiwan, C=TW
❺ Step 5: Create certificate signing request (CSR)
❻ Step 6: Sign the certificate
Certificate request self-signature ok
subject=C=TW, ST=Taiwan, L=Taipei, O=My Company, OU=IT Department, CN=mycompany.com.tw
❼ Step 7: Import CA into keystore
Certificate was added to keystore
❽ Step 8: Import signed certificate into keystore
Certificate reply was installed in keystore
🎉 Successfully generated certificates for Kafka!
```

The script will generate the following files:

- `certs/ca-cert`
- `certs/ca-cert.srl`
- `certs/ca-key`
- `certs/kafka_keystore_creds`
- `certs/kafka_ssl_key_creds`
- `certs/kafka_truststore_creds`
- `certs/kafka-cluster-cert`
- `certs/kafka-cluster-cert-signed`
- `certs/kafka.keystore.jks`
- `certs/kafka.truststore.jks`
- `.env`

### 2. Start the Kafka cluster

Once the certificates are generated, you can start the Kafka cluster using Docker Compose:

```bash
docker-compose up -d
```

> **Info**
> 
> This command will run the Kafka brokers in detached mode, allowing them to run in the background.

### 3. Done

You can now access the Kafka cluster via the web interface at [`http://localhost:8888`](http://localhost:8888). Use this interface to interact with your Kafka brokers, manage topics, and monitor cluster health.

### 4. Clean up

To stop the Kafka cluster, run the following command:

```bash
docker-compose down
```