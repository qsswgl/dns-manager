#!/bin/bash
set -e

# Deploy Envoy on Aliyun (www.qsgl.cn)
REG="43.138.35.183:5000"

# Backup docker daemon.json if exists
if [ -f /etc/docker/daemon.json ]; then
  cp /etc/docker/daemon.json /etc/docker/daemon.json.bak_$(date +%F_%T)
fi

# Write insecure registry config
cat >/etc/docker/daemon.json <<JSON
{
  "insecure-registries": ["$REG"]
}
JSON

# Restart docker
if command -v systemctl >/dev/null 2>&1; then
  systemctl restart docker || (sleep 2 && systemctl restart docker)
else
  service docker restart || true
fi

# Prepare cert dir
mkdir -p /opt/envoy/certs
chown root:root /opt/envoy/certs
chmod 755 /opt/envoy/certs

# Pull image
docker pull 43.138.35.183:5000/envoy:envoy-v1.31-custom || true

# Stop and remove old container if exists
if docker ps -a --format '{{.Names}}' | grep -q '^envoy-proxy$'; then
  docker rm -f envoy-proxy || true
fi

# Run new container mapping host 8443 to container 443
# Expose 99 and 9901 as well
docker run -d --name envoy-proxy --restart unless-stopped -p 8443:443 -p 99:99 -p 9901:9901 -v /opt/envoy/certs:/etc/envoy/certs 43.138.35.183:5000/envoy:envoy-v1.31-custom || \
  docker run -d --name envoy-proxy --restart unless-stopped -p 8443:443 -p 99:99 -p 9901:9901 -v /opt/envoy/certs:/etc/envoy/certs envoy:envoy-v1.31-custom || true

# Create renew script
cat >/usr/local/bin/renew-qsgl-cert.sh <<'SH'
#!/bin/bash
set -e
OUTDIR=/opt/envoy/certs
API="https://tx.qsgl.net:5075/api/request-cert"
TMP=$(mktemp)

# Request certificate from tx (expects JSON with fields "cert" and "key")
curl -fsS -X POST -H "Content-Type: application/json" -d '{"domain":"qsgl.net","provider":"DNSPOD"}' "$API" -o "$TMP" || { echo "curl failed" >&2; rm -f "$TMP"; exit 1; }

if command -v python3 >/dev/null 2>&1; then
  python3 - <<PY "$TMP"
import json,sys,os
p=sys.argv[1]
j=json.load(open(p))
cert=j.get('cert')
key=j.get('key')
if cert and key:
  open('/opt/envoy/certs/qsgl.net.crt','w').write(cert)
  open('/opt/envoy/certs/qsgl.net.key','w').write(key)
  os.chmod('/opt/envoy/certs/qsgl.net.crt',0o644)
  os.chmod('/opt/envoy/certs/qsgl.net.key',0o600)
  print('wrote cert/key')
  sys.exit(0)
print('no cert/key in json',file=sys.stderr)
sys.exit(2)
PY
else
  echo 'python3 not available' >&2
  rm -f "$TMP"
  exit 2
fi
rm -f "$TMP"
# restart envoy to pick up certs
docker restart envoy-proxy || true
SH

chmod +x /usr/local/bin/renew-qsgl-cert.sh

# Create check-and-renew script
cat >/usr/local/bin/check-and-renew-qsgl.sh <<'SH'
#!/bin/bash
set -e
CRT=/opt/envoy/certs/qsgl.net.crt
if [ ! -f "$CRT" ]; then /usr/local/bin/renew-qsgl-cert.sh; exit 0; fi
end=$(openssl x509 -enddate -noout -in "$CRT" 2>/dev/null | sed 's/^notAfter=//')
if [ -z "$end" ]; then /usr/local/bin/renew-qsgl-cert.sh; exit 0; fi
endsec=$(date -d "$end" +%s)
now=$(date +%s)
days=$(( (endsec - now) / 86400 ))
if [ $days -le 3 ]; then /usr/local/bin/renew-qsgl-cert.sh; fi
SH

chmod +x /usr/local/bin/check-and-renew-qsgl.sh

# Run once now
/usr/local/bin/check-and-renew-qsgl.sh || true

# Install cron job
cat >/etc/cron.d/renew-qsgl <<CR
# run daily at 03:10
10 3 * * * root /usr/local/bin/check-and-renew-qsgl.sh >> /var/log/renew-cert.log 2>&1
CR

# Ensure cron is running
if command -v systemctl >/dev/null 2>&1; then
  systemctl restart cron || true
else
  service cron restart || true
fi

# Done
echo DEPLOY_DONE
