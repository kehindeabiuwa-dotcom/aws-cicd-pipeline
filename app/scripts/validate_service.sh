#!/bin/bash
# validate_service.sh
# Runs during the ValidateService lifecycle hook.
# Performs a quick HTTP health check against the local web server.
# A non-zero exit code tells CodeDeploy the deployment failed and
# triggers an automatic rollback (when rollback is enabled on the group).

set -e

echo "=== validate_service.sh started ==="

MAX_RETRIES=5
RETRY_INTERVAL=5
APP_URL="http://localhost/nextwork-web-project/"

for i in $(seq 1 $MAX_RETRIES); do
    echo "Health check attempt $i of $MAX_RETRIES..."
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL" || true)

    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "Application is healthy (HTTP $HTTP_STATUS)"
        echo "=== validate_service.sh completed ==="
        exit 0
    fi

    echo "Got HTTP $HTTP_STATUS, retrying in ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
done

echo "ERROR: Application did not become healthy after $MAX_RETRIES attempts."
echo "=== validate_service.sh failed — triggering rollback ==="
exit 1
