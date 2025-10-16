#!/bin/bash
echo "启动 DNS API 服务..."
export ASPNETCORE_URLS="http://0.0.0.0:5074;https://0.0.0.0:5075"
chmod +x ./DNSApi
./DNSApi