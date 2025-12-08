#!/bin/bash
apt-get update -y
apt-get install -y nginx

# Replace default site
cat <<EOF >/var/www/html/index.html
<html>
  <body>
    <h1>Terraform App Instance Healthy Checker</h1>
  </body>
</html>
EOF

systemctl enable nginx
systemctl restart nginx

# Add simple health endpoint
echo "healthy" > /var/www/html/health
