#!/bin/bash
# stop_server.sh
# Runs during the ApplicationStop lifecycle hook.
# Gracefully stops Apache HTTPD and Tomcat if they are currently running.
# Using pgrep before stopping avoids a non-zero exit code when the
# service isn't running (e.g., on a fresh instance with no prior deployment).

echo "=== stop_server.sh started ==="

if pgrep httpd > /dev/null 2>&1; then
    echo "Stopping Apache HTTPD..."
    systemctl stop httpd.service
else
    echo "Apache HTTPD is not running, skipping."
fi

if pgrep -x "java" > /dev/null 2>&1; then
    echo "Stopping Tomcat..."
    systemctl stop tomcat.service
else
    echo "Tomcat is not running, skipping."
fi

echo "=== stop_server.sh completed ==="
