#!/bin/bash
# Envoy 配置生成脚本
# 根据 /etc/envoy-domain.conf 中的域名自动生成 Envoy 配置

set -euo pipefail

# 读取配置的域名
if [ -f "/etc/envoy-domain.conf" ]; then
    DOMAIN=$(grep -v '^#' /etc/envoy-domain.conf | grep -v '^$' | head -n 1 | tr -d '[:space:]')
else
    DOMAIN="qsgl.cn"
fi

echo "生成 Envoy 配置，域名: $DOMAIN"

# 生成配置文件
cat > /opt/envoy/envoy.yaml <<EOF
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901

static_resources:
  listeners:
  # HTTP 80 → HTTPS 443 重定向
  - name: http_redirect_80
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 80
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          codec_type: AUTO
          route_config:
            name: http_redirect
            virtual_hosts:
            - name: redirect_vhost
              domains: ["$DOMAIN", "*.$DOMAIN"]
              routes:
              - match: { prefix: "/" }
                redirect: { https_redirect: true }
          http_filters:
          - name: envoy.filters.http.router
            typed_config: { "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router }

  # HTTPS 443 终止TLS并反代到上游 61.163.200.245:443
  - name: https_listener_443
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 443
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_https
          codec_type: AUTO
          route_config:
            name: https_route
            virtual_hosts:
            - name: ${DOMAIN//./_}_backend
              domains: ["$DOMAIN", "*.$DOMAIN", "$DOMAIN:443", "*.$DOMAIN:443", "$DOMAIN:8443", "*.$DOMAIN:8443"]
              routes:
              - match: { prefix: "/" }
                route:
                  cluster: qsgl_backend
                  host_rewrite_literal: www.qsgl.net
          http_filters:
          - name: envoy.filters.http.router
            typed_config: { "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router }
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
          common_tls_context:
            tls_certificates:
            - certificate_chain: { filename: "/etc/envoy/certs/$DOMAIN.crt" }
              private_key:      { filename: "/etc/envoy/certs/$DOMAIN.key" }

  # HTTPS 99 终止TLS并反代到上游 61.163.200.245:99
  - name: https_listener_99
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 99
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_https_99
          codec_type: AUTO
          route_config:
            name: https_route_99
            virtual_hosts:
            - name: ${DOMAIN//./_}_backend_99
              domains: ["www.$DOMAIN", "www.$DOMAIN:99", "$DOMAIN:99", "*.$DOMAIN:99"]
              routes:
              - match: { prefix: "/" }
                route:
                  cluster: qsgl_backend_99
                  host_rewrite_literal: www.qsgl.net
          http_filters:
          - name: envoy.filters.http.router
            typed_config: { "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router }
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
          common_tls_context:
            tls_certificates:
            - certificate_chain: { filename: "/etc/envoy/certs/$DOMAIN.crt" }
              private_key:      { filename: "/etc/envoy/certs/$DOMAIN.key" }

  # HTTPS 5002 终止TLS并反代到上游 61.163.200.245:5002
  - name: https_listener_5002
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 5002
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_https_5002
          codec_type: AUTO
          route_config:
            name: https_route_5002
            virtual_hosts:
            - name: ${DOMAIN//./_}_backend_5002
              domains: ["www.$DOMAIN", "www.$DOMAIN:5002", "$DOMAIN:5002", "*.$DOMAIN:5002"]
              routes:
              - match: { prefix: "/" }
                route:
                  cluster: qsgl_backend_5002
                  host_rewrite_literal: www.qsgl.net
          http_filters:
          - name: envoy.filters.http.router
            typed_config: { "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router }
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
          common_tls_context:
            tls_certificates:
            - certificate_chain: { filename: "/etc/envoy/certs/$DOMAIN.crt" }
              private_key:      { filename: "/etc/envoy/certs/$DOMAIN.key" }

  clusters:
  - name: qsgl_backend
    connect_timeout: 30s
    type: LOGICAL_DNS
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: qsgl_backend
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 61.163.200.245
                port_value: 443
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: www.qsgl.net

  - name: qsgl_backend_5002
    connect_timeout: 30s
    type: LOGICAL_DNS
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: qsgl_backend_5002
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 61.163.200.245
                port_value: 5002
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: www.qsgl.net

  - name: qsgl_backend_99
    connect_timeout: 30s
    type: LOGICAL_DNS
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: qsgl_backend_99
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 61.163.200.245
                port_value: 99
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: www.qsgl.net
EOF

echo "Envoy 配置已生成: /opt/envoy/envoy.yaml"
echo "域名: $DOMAIN"
echo "证书文件:"
echo "  - /etc/envoy/certs/$DOMAIN.crt"
echo "  - /etc/envoy/certs/$DOMAIN.key"
