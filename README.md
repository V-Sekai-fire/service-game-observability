# service-game-observability

Metrics, log and trace stores behind an OTLP collector, run as rootless containers that systemd quadlets manage.

## What it is for

Services send OTLP to the collector, which routes each signal to its store; all of them share one pod and keep their data on named volumes. The query interfaces need an authenticating proxy before they are exposed beyond the host.

## Build and run

Copy the quadlet units and the collector configuration into the user's systemd container directory, reload systemd, and start the units. `AGENTS.md` lists the commands.

## Licence

The licence is not stated.
