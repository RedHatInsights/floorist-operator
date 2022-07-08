#!/bin/bash

generate_password () {
    cat /dev/urandom | tr -dc '[:alnum:]' | fold -w ${1:-30} | head -n 1
}

SECRETSDIR=$( dirname -- "${BASH_SOURCE[0]}" )/.secrets

DATABASE="$SECRETSDIR"/database.txt
DB_USER=$(generate_password)
DB_PASS=$(generate_password)
DB_ADMIN_PASS=$(generate_password)

cat << EOF > $DATABASE
db.host=database
db.port=5432
db.user=${DB_USER}
db.password=${DB_PASS}
db.name=mydatabase
db.admin_user=postgres
db.admin_password=${DB_ADMIN_PASS}
EOF

MINIO="$SECRETSDIR"/minio.txt
KEY_ID=$(generate_password)
ACCESS_KEY=$(generate_password)

cat <<EOF > $MINIO
aws_access_key_id=${KEY_ID}
aws_region=us-east-1
aws_secret_access_key=${ACCESS_KEY}
bucket=mybucket
endpoint=http://objectstore:9000
hostname=objectstore
port=9000
EOF
