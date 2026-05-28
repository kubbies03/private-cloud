#!/bin/bash
# Generate self-signed wildcard cert for *.lab.local
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout lab.key \
  -out lab.crt \
  -subj "/C=VN/ST=HCM/L=HoChiMinh/O=PrivateCloudLab/CN=*.lab.local" \
  -extensions v3_req \
  -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = VN
ST = HCM
L = HoChiMinh
O = PrivateCloudLab
CN = *.lab.local

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.lab.local
DNS.2 = lab.local
DNS.3 = api.lab.local
DNS.4 = grafana.lab.local
DNS.5 = prometheus.lab.local
EOF
)

echo "Certificate generated: lab.crt / lab.key"
