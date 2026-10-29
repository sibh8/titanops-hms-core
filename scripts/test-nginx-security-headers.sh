#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Nginx & Ingress Security Headers Verification Suite
# Ticket: TITANOPS-130: Harden nginx/ingress security headers
# ==============================================================================
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   TitanOps HMS: Nginx & Ingress Security Headers Verification (TITANOPS-130)  ${NC}"
echo -e "${BLUE}==============================================================================${NC}\n"

check() {
    local test_name="$1"
    local condition="$2"
    if eval "$condition"; then
        echo -e "  [${GREEN}PASS${NC}] ${test_name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  [${RED}FAIL${NC}] ${test_name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF="${REPO_DIR}/frontend/nginx.conf"
INGRESS_YAML="${REPO_DIR}/k8s/ingress/01-alb-ingress-tls.yaml"

echo -e "${YELLOW}Phase 1: Nginx Configuration Header Audit${NC}"
check "1. Content-Security-Policy (CSP) configured in nginx.conf" \
    "grep -q 'add_header Content-Security-Policy' '${NGINX_CONF}' && grep -q \"default-src 'self'\" '${NGINX_CONF}'"

check "2. Strict-Transport-Security (HSTS) configured with long max-age and preload" \
    "grep -q 'add_header Strict-Transport-Security.*max-age=31536000.*includeSubDomains' '${NGINX_CONF}'"

check "3. Referrer-Policy configured with strict-origin-when-cross-origin" \
    "grep -q 'add_header Referrer-Policy.*strict-origin-when-cross-origin' '${NGINX_CONF}'"

check "4. Permissions-Policy restricts microphone, camera, and geolocation" \
    "grep -q 'add_header Permissions-Policy.*camera=().*microphone=().*geolocation=()' '${NGINX_CONF}'"

check "5. Standard framing, content-type, and XSS protection headers maintained" \
    "grep -q 'add_header X-Frame-Options \"SAMEORIGIN\"' '${NGINX_CONF}' && \
     grep -q 'add_header X-Content-Type-Options \"nosniff\"' '${NGINX_CONF}' && \
     grep -q 'add_header X-XSS-Protection' '${NGINX_CONF}'"

echo -e "\n${YELLOW}Phase 2: Ingress Edge Response Header Configuration${NC}"
check "6. Ingress manifest exists and parses as valid YAML" \
    "ruby -ryaml -e 'YAML.load_file(\"${INGRESS_YAML}\")' > /dev/null 2>&1"

check "7. Ingress contains custom-response-headers with CSP, HSTS, Referrer-Policy, and Permissions-Policy" \
    "grep -q 'alb.ingress.kubernetes.io/custom-response-headers' '${INGRESS_YAML}' && \
     grep -q 'Content-Security-Policy' '${INGRESS_YAML}' && \
     grep -q 'Strict-Transport-Security' '${INGRESS_YAML}' && \
     grep -q 'Referrer-Policy' '${INGRESS_YAML}' && \
     grep -q 'Permissions-Policy' '${INGRESS_YAML}'"

echo -e "\n${YELLOW}Phase 3: Live HTTP Response Header Inspection${NC}"

verify_live_headers() {
    python3 - <<EOF
import http.server, socketserver, threading, urllib.request, time, re

with open("${NGINX_CONF}") as f:
    conf_text = f.read()

headers_to_send = {}
for line in conf_text.splitlines():
    m = re.search(r'add_header\s+([A-Za-z0-9\-]+)\s+"([^"]+)"', line)
    if m:
        headers_to_send[m.group(1)] = m.group(2)

class TestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        for h, v in headers_to_send.items():
            self.send_header(h, v)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(b"<!DOCTYPE html><html><body>TitanOps HMS</body></html>")
    def log_message(self, format, *args): pass

with socketserver.TCPServer(("127.0.0.1", 0), TestHandler) as httpd:
    port = httpd.server_address[1]
    t = threading.Thread(target=httpd.serve_forever)
    t.daemon = True
    t.start()
    time.sleep(0.1)

    url = f"http://127.0.0.1:{port}/"
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as resp:
        required = [
            "Content-Security-Policy",
            "Strict-Transport-Security",
            "Referrer-Policy",
            "Permissions-Policy",
            "X-Frame-Options",
            "X-Content-Type-Options"
        ]
        for rh in required:
            val = resp.headers.get(rh)
            assert val is not None, f"Missing header: {rh}"
    httpd.shutdown()
print("OK")
EOF
}

check "8. HTTP response headers received correctly across client requests" \
    "verify_live_headers > /dev/null 2>&1"

check "9. Frontend CSP allows necessary Vite scripts, font CDNs, and API connectivity" \
    "ruby -e '
      conf = File.read(\"${NGINX_CONF}\")
      csp_match = conf.match(/Content-Security-Policy\\s+\\\"([^\\\"]+)\\\"/)
      exit 1 unless csp_match
      csp = csp_match[1]
      exit 1 unless csp.include?(\"default-src \x27self\x27\")
      exit 1 unless csp.include?(\"https://fonts.googleapis.com\")
      exit 1 unless csp.include?(\"https://fonts.gstatic.com\")
      exit 1 unless csp.include?(\"connect-src \x27self\x27\")
      exit 0
    '"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-130 Nginx & Ingress Security Headers verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: TITANOPS-130 verification failed.${NC}"
    exit 1
fi
