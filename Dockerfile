# syntax=docker/dockerfile:1
# Observability stack: VictoriaMetrics (metrics) + VictoriaLogs (logs) +
# Jaeger all-in-one (traces) + OpenTelemetry Collector (ingest router).
# All processes managed by supervisord in a single Fly Machine.

FROM victoriametrics/victoria-metrics:latest AS vm
FROM victoriametrics/victoria-logs:latest AS vl
FROM otel/opentelemetry-collector-contrib:latest AS otelcol
FROM jaegertracing/all-in-one:latest AS jaeger

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        supervisor \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=vm      /victoria-metrics-prod        /usr/local/bin/victoria-metrics
COPY --from=vl      /victoria-logs-prod           /usr/local/bin/victoria-logs
COPY --from=otelcol /otelcol-contrib              /usr/local/bin/otelcol
COPY --from=jaeger  /go/bin/all-in-one-linux      /usr/local/bin/jaeger

RUN chmod +x /usr/local/bin/victoria-metrics \
             /usr/local/bin/victoria-logs \
             /usr/local/bin/otelcol \
             /usr/local/bin/jaeger

RUN mkdir -p /var/lib/victoriametrics \
             /var/lib/victorialogs \
             /var/lib/jaeger/data \
             /var/lib/jaeger/keys

COPY supervisord.conf           /etc/supervisor/conf.d/observability.conf
COPY otel-collector-config.yaml /etc/otel-collector-config.yaml

# OTLP ingest (internal): 4317 gRPC, 4318 HTTP
# VictoriaMetrics query/UI: 8428
# VictoriaLogs query/UI:    9428
# Jaeger UI:                16686
EXPOSE 4317 4318 8428 9428 16686

CMD ["supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
