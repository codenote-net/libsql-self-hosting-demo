#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="${ROOT_DIR}/.local/certs"

mkdir -p "${CERT_DIR}"

if [[ -f "${CERT_DIR}/ca_cert.pem" && -f "${CERT_DIR}/server_cert.pem" && -f "${CERT_DIR}/client_cert.pem" ]]; then
  echo "Development certificates already exist in ${CERT_DIR}"
  exit 0
fi

openssl genrsa -out "${CERT_DIR}/ca_key.pem" 4096
openssl req -x509 -new -nodes -key "${CERT_DIR}/ca_key.pem" -sha256 -days 30 \
  -subj "/CN=libsql-demo-local-ca" -out "${CERT_DIR}/ca_cert.pem"

openssl genrsa -out "${CERT_DIR}/server_key.pem" 2048
openssl req -new -key "${CERT_DIR}/server_key.pem" -subj "/CN=primary" \
  -out "${CERT_DIR}/server.csr"
openssl x509 -req -in "${CERT_DIR}/server.csr" -CA "${CERT_DIR}/ca_cert.pem" \
  -CAkey "${CERT_DIR}/ca_key.pem" -CAcreateserial -out "${CERT_DIR}/server_cert.pem" \
  -days 30 -sha256 -extfile <(printf "subjectAltName=DNS:primary,DNS:localhost,IP:127.0.0.1\n")

openssl genrsa -out "${CERT_DIR}/client_key.pem" 2048
openssl req -new -key "${CERT_DIR}/client_key.pem" -subj "/CN=replica" \
  -out "${CERT_DIR}/client.csr"
openssl x509 -req -in "${CERT_DIR}/client.csr" -CA "${CERT_DIR}/ca_cert.pem" \
  -CAkey "${CERT_DIR}/ca_key.pem" -CAcreateserial -out "${CERT_DIR}/client_cert.pem" \
  -days 30 -sha256

rm -f "${CERT_DIR}/server.csr" "${CERT_DIR}/client.csr" "${CERT_DIR}/ca_cert.srl"
chmod 600 "${CERT_DIR}"/*_key.pem
chmod 644 "${CERT_DIR}"/*_cert.pem

echo "Generated development-only certificates in ${CERT_DIR}"
