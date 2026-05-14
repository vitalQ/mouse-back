#!/bin/sh
set -eu

BUNDLE_ID="local.mouseback.app"

tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Reset permissions for $BUNDLE_ID"
echo "Open System Settings and grant Accessibility + Input Monitoring to dist/MouseBack.app again."
