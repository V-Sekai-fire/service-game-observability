# multiplayer-fabric-observability

Metrics, logs, and traces for the V-Sekai-fire platform, deployed as a single Fly Machine.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| VictoriaMetrics | 8428 | Metrics storage and PromQL |
| VictoriaLogs | 9428 | Log storage and query |
| Jaeger all-in-one | 16686 | Trace storage and query (UI) |
| OTEL Collector | 4317 (gRPC), 4318 (HTTP) | OTLP ingest, routes to the above |

All four run under supervisord. Data persists on an `observability_data` volume at `/var/lib`.

## Deploying

### First time

```bash
fly apps create multiplayer-fabric-observability
fly volumes create observability_data --app multiplayer-fabric-observability --region iad --size 10
flyctl deploy --app multiplayer-fabric-observability
```

### Ongoing

Push to `main` — the deploy workflow runs automatically.

## Sending telemetry from other Fly apps

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
  otlp_endpoint: "http://multiplayer-fabric-observability.internal:4317"

config :opentelemetry,
  resource: [service: [name: "my-service", version: "1.0.0"]]
```

### Docker / other services

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://multiplayer-fabric-observability.internal:4318
OTEL_SERVICE_NAME=my-service
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production
```

### Set as a Fly secret

```bash
fly secrets set \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://multiplayer-fabric-observability.internal:4318 \
  --app multiplayer-fabric-gateway
```

## Querying

```bash
fly proxy 8428:8428   --app multiplayer-fabric-observability   # VictoriaMetrics
fly proxy 9428:9428   --app multiplayer-fabric-observability   # VictoriaLogs
fly proxy 16686:16686 --app multiplayer-fabric-observability   # Jaeger UI
```

Public URLs (add basic auth before exposing):
- `http://multiplayer-fabric-observability.fly.dev:8428/vmui/`
- `http://multiplayer-fabric-observability.fly.dev:9428/`
- `http://multiplayer-fabric-observability.fly.dev:16686/`

## Data retention

- Metrics: 12 months (`-retentionPeriod=12`)
- Logs: disk-bound (no explicit limit)
- Traces: disk-bound (Badger local storage, no explicit TTL configured)

## Files

| Path | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build; copies binaries from official images |
| `supervisord.conf` | Process management for all four services |
| `otel-collector-config.yaml` | OTLP routing rules |
| `fly.toml` | Fly.io app config with persistent volume |
| `.github/workflows/deploy.yml` | Deploy on push to main |

## Conventions

- Keep the app in `iad` (same region as gateway, crdb, uro).
- OTLP ports 4317 and 4318 must not be exposed publicly — they accept unauthenticated writes.
- Add HTTP basic auth to ports 8428, 9428, and 16686 before public exposure.
