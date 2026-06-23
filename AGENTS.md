# multiplayer-fabric-observability

Metrics, logs, and traces for the V-Sekai-fire platform, deployed as rootless
Podman containers managed by systemd quadlets.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| VictoriaMetrics | 8428 | Metrics storage and PromQL |
| VictoriaLogs | 9428 | Log storage and query |
| VictoriaTraces | 10428 | Trace storage and query |
| OTEL Collector | 4317 (gRPC), 4318 (HTTP) | OTLP ingest, routes to the above |

All four run in a shared Podman pod so they communicate via `localhost`. Named
Podman volumes (`observability-metrics`, `observability-logs`,
`observability-traces`) hold persistent data.

## Installing

Requires Podman ≥ 4.4 and systemd ≥ 250 (quadlet support built-in).

```bash
# 1. Create the quadlet drop-in directory
mkdir -p ~/.config/containers/systemd

# 2. Copy unit files and otel config
cp quadlet/* ~/.config/containers/systemd/
cp otel-collector-config.yaml ~/.config/containers/systemd/

# 3. Reload systemd so quadlet generator runs
systemctl --user daemon-reload

# 4. Enable and start everything
systemctl --user enable --now \
    observability-pod.service \
    victoria-metrics.service \
    victoria-logs.service \
    victoria-traces.service \
    otel-collector.service
```

### Verify

```bash
systemctl --user status victoria-metrics victoria-logs victoria-traces otel-collector
podman pod ps
```

### Updating images

```bash
podman pull victoriametrics/victoria-metrics:latest \
           victoriametrics/victoria-logs:latest \
           victoriametrics/victoria-traces:latest \
           otel/opentelemetry-collector-contrib:latest
systemctl --user restart victoria-metrics victoria-logs victoria-traces otel-collector
```

## Sending telemetry from other services

### Elixir / Phoenix

Add to `mix.exs`:
```elixir
{:opentelemetry_exporter, "~> 1.6"},
{:opentelemetry, "~> 1.4"},
```

Add to `config/runtime.exs`:
```elixir
config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317"

config :opentelemetry,
  resource: [service: [name: "my-service", version: "1.0.0"]]
```

### Docker / other services

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://<host>:4318
OTEL_SERVICE_NAME=my-service
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production
```

## Querying

```bash
# Access UIs directly (ports published by the pod)
open http://localhost:8428/vmui/   # VictoriaMetrics
open http://localhost:9428/        # VictoriaLogs
open http://localhost:10428/       # VictoriaTraces
```

Add HTTP basic auth via a reverse proxy (nginx, Caddy) before public exposure.

## Data retention

- Metrics: 12 months (`-retentionPeriod=12`)
- Logs: disk-bound (no explicit limit)
- Traces: disk-bound (Badger local storage, no explicit TTL configured)

## Files

| Path | Purpose |
|------|---------|
| `quadlet/observability.pod` | Podman pod — shared network, port publishing |
| `quadlet/victoria-metrics.container` | VictoriaMetrics quadlet unit |
| `quadlet/victoria-logs.container` | VictoriaLogs quadlet unit |
| `quadlet/victoria-traces.container` | VictoriaTraces quadlet unit |
| `quadlet/otel-collector.container` | OTel Collector quadlet unit |
| `quadlet/observability-{metrics,logs,traces}.volume` | Named Podman volumes |
| `otel-collector-config.yaml` | OTLP routing rules (copied to systemd dir on install) |

## Conventions

- OTLP ports 4317 and 4318 must not be exposed publicly — they accept unauthenticated writes.
- Add HTTP basic auth to ports 8428, 9428, and 10428 before public exposure.
- All containers share the pod's `localhost`; the OTel Collector config targets `localhost:<port>` for each backend.
