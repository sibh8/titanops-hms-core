#!/bin/sh
set -e

# Detect local nameserver and Kubernetes search domain if running in a cluster
NS=$(awk '$1=="nameserver" {print $2; exit}' /etc/resolv.conf 2>/dev/null || true)
SEARCH=$(grep "^search" /etc/resolv.conf 2>/dev/null | awk '{print $2}' || true)

CONF_FILE="/etc/nginx/conf.d/medicore.conf"

if [ -f "$CONF_FILE" ]; then
    if [ -n "$SEARCH" ] && echo "$SEARCH" | grep -q "\.svc\.cluster\.local"; then
        # Running inside Kubernetes
        if [ -n "$NS" ]; then
            sed -i "s|resolver .* valid=10s ipv6=off;|resolver $NS 127.0.0.11 valid=10s ipv6=off;|" "$CONF_FILE"
        fi
        sed -i "s|\([a-z\-]*\-service\):|\1.$SEARCH:|g" "$CONF_FILE"
        sed -i "s|otel-collector:4318|otel-collector.$SEARCH:4318|g" "$CONF_FILE"
    fi
fi
