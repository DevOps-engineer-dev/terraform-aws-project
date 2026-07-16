#!/bin/bash
set -euo pipefail

dnf update -y
dnf install -y httpd

HOSTNAME=$(hostname -f)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")" http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /var/www/html/index.html <<EOF
<html>
  <head><title>Web Server</title></head>
  <body>
    <h1>Hello from ${HOSTNAME}</h1>
    <p>Availability zone: ${AZ}</p>
  </body>
</html>
EOF

systemctl enable httpd
systemctl start httpd
