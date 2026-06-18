#!/bin/bash
# start_server.sh
# Runs during the ApplicationStart lifecycle hook.
# Starts Tomcat and Apache HTTPD immediately, and enables both services
# to auto-start on instance reboot.

set -e

echo "=== start_server.sh started ==="

systemctl start tomcat.service
systemctl enable tomcat.service

systemctl start httpd.service
systemctl enable httpd.service

echo "Tomcat status: $(systemctl is-active tomcat.service)"
echo "Apache status: $(systemctl is-active httpd.service)"

echo "=== start_server.sh completed ==="
