#!/bin/bash
# install_dependencies.sh
# Runs during the BeforeInstall lifecycle hook.
# Installs Tomcat and Apache HTTPD, then configures Apache to proxy
# incoming HTTP traffic (port 80) to Tomcat (port 8080).

set -e

echo "=== install_dependencies.sh started ==="

# Update package index
dnf update -y

# Install Java (required by Tomcat), Tomcat, and Apache HTTPD
dnf install -y java-1.8.0-amazon-corretto tomcat tomcat-webapps httpd

# Enable mod_proxy and mod_proxy_http so Apache can forward requests to Tomcat
cat > /etc/httpd/conf.d/tomcat-proxy.conf << 'EOF'
<VirtualHost *:80>
    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
EOF

# Ensure the Tomcat webapps directory is writable by the CodeDeploy agent
chown -R tomcat:tomcat /usr/share/tomcat/webapps/
chmod -R 755 /usr/share/tomcat/webapps/

echo "=== install_dependencies.sh completed ==="
