#!/bin/bash

yum install -y yum-utils shadow-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install boundary-enterprise

# Get token for fetching metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Use the token to fetch the public IP address
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s "http://169.254.169.254/latest/meta-data/public-ipv4")

# Create the Boundary configuration directory
mkdir -p /etc/boundary

# Boundary worker configuration
cat > /etc/boundary/config.hcl <<- EOF
disable_mlock = true

hcp_boundary_cluster_id = "${BOUNDARY_CLUSTER_ID}"

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}

worker {
  public_addr = "$${PUBLIC_IP}"
  auth_storage_path = "/etc/boundary/worker-${WORKER_ID}"
  tags {
    type = ${WORKER_TAGS}
    project = ${WORKER_PROJECT_TAG}
    region = ${WORKER_REGION_TAG}
  }

  controller_generated_activation_token = "${CONTROLLER_GENERATED_ACTIVATION_TOKEN}"
}
EOF

# Create systemd service file
cat > /etc/systemd/system/boundary.service <<- EOF
[Unit]
Description=Boundary Worker
[Service]
ExecStart=/usr/bin/boundary server -config="/etc/boundary/config.hcl"
User=boundary
Group=boundary
[Install]
WantedBy=multi-user.target
EOF

# Adding a system user and group
useradd --system --user-group boundary || true

# Changing ownership of directories and files
chown boundary:boundary -R /etc/boundary
chown boundary:boundary /usr/bin/boundary

# Setting permissions for the systemd service file and managing the service
chmod 664 /etc/systemd/system/boundary.service
systemctl daemon-reload
systemctl enable boundary
systemctl start boundary
