# AGENTS.md — multiplayer-fabric-observability

Unified observability stack (metrics, logs, traces) for the V-Sekai-fire platform.
Deployed as `multiplayer-fabric-observability` on Fly.io.

## Architecture

| Service | Port | Purpose |
|---------|------|---------|
| VictoriaMetrics | 8428 | Metrics storage + PromQL query |
| VictoriaLogs | 9428 | Log storage + query UI |
| Grafana Tempo | 3200 | Distributed traces storage + UI |
| OTEL Collector | 4317 (gRPC), 4318 (HTTP) | OTLP ingest, routes to the three backends |

All four services run in a single Fly Machine managed by supervisord.
Data persists on a `observability_data` volume mounted at `/var/lib`.

## Deploying

### First time

```bash
cd /tmp/multiplayer-fabric-observability
fly apps create multiplayer-fabric-observability --org v-sekai-fire
fly volumes create observability_data --app multiplayer-fabric-observability --region iad --size 10
fly secrets set FLY_API_TOKEN=<token> --app multiplayer-fabric-observability
flyctl deploy --app multiplayer-fabric-observability
```

### Ongoing

Push to `main` — the deploy workflow runs automatically.

## Sending telemetry from other Fly apps

### Elixir / Phoenix (OpenTelemetry)

Add to `mix.exs`:
```elixir
{:opentelemetry_exporter, "~> 1.6"},
{:opentelemetry, "~> 1.4"},
```

Add to `config/runtime.exs`:
```elixir
config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://multiplayer-fabric-observability.internal:4317"

config :opentelemetry,
  resource: [service: [name: "my-service", version: "1.0.0"]]
```

### Docker / other services

Set environment variables:
```
OTEL_EXPORTER_OTLP_ENDPOINT=http://multiplayer-fabric-observability.internal:4318
OTEL_SERVICE_NAME=my-service
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production
```

### Fly secret (OTEL endpoint)

For convenience, set a shared secret on each app:

```bash
fly secrets set \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://multiplayer-fabric-observability.internal:4318 \
  --app multiplayer-fabric-gateway
```

## Querying data

All UIs are accessible at:

- **VictoriaMetrics**: `http://multiplayer-fabric-observability.fly.dev:8428/vmui/`
- **VictoriaLogs**: `http://multiplayer-fabric-observability.fly.dev:9428/`
- **Tempo**: `http://multiplayer-fabric-observability.fly.dev:3200/`

Or proxy locally:

```bash
fly proxy 8428:8428 --app multiplayer-fabric-observability   # VictoriaMetrics
fly proxy 9428:9428 --app multiplayer-fabric-observability   # VictoriaLogs
fly proxy 3200:3200 --app multiplayer-fabric-observability   # Tempo
```

## Data retention

- Metrics (VictoriaMetrics): 12 months (`-retentionPeriod=12`)
- Logs (VictoriaLogs): no explicit limit — disk-bound
- Traces (Tempo): 30 days (`block_retention: 720h`)

## Files

| Path | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build copying binaries from official images |
| `supervisord.conf` | Process management for all four services |
| `otel-collector-config.yaml` | OTLP ingest routing rules |
| `tempo-config.yaml` | Tempo trace storage and span-metrics config |
| `fly.toml` | Fly.io app config with persistent volume |
| `.github/workflows/deploy.yml` | Auto-deploy on push to main |

## Conventions

- The observability app must stay in `iad` (same region as gateway, crdb, uro).
- Never expose OTLP ports (4317, 4318) to the public internet — they accept unauthenticated writes.
- Add HTTP basic auth to the UI ports (8428, 9428, 3200) before exposing publicly.
