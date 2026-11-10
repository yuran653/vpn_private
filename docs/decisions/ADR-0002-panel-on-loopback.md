# ADR-0002: Panel on loopback, installed from a pinned release

- Status: accepted; the subscription-service line is superseded by ADR-0010 (on, loopback only, reached through the tunnel)
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-deploy-vless-reality/`

## Context

The project must prevent panel discovery. 3x-ui is a root process with a web interface, and its installer is interactive by default and prints the credentials it generates.

## Decision

- The panel listens on 127.0.0.1 only. It is reached through an SSH tunnel (`ssh -L`). No firewall rule is ever opened for it.
- The subscription service is off. It listens on every interface and one client does not need it.
- 3x-ui is installed by its own `install.sh`, fetched from the release tag pinned in `scripts/deploy-vpn.sh`, checked against a SHA-256 in that script, and run in non-interactive mode with its output sent to a root-only log.
- All configuration after the install goes through the panel's HTTP API on loopback, with the API token the installer wrote to `/etc/x-ui/install-result.env`.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Panel on a public port behind a random path and TLS | It still answers a scanner, and a panel flaw is then reachable from the internet. |
| Unpack the release tarball by hand | Repeats the installer's unit and sandbox setup and breaks on the next release. |
| Write inbounds straight into the panel database | Tied to the schema. The API is described by the panel's own OpenAPI file. |
| Install the latest release each time | A run would not be reproducible, and the API could change under the script. |

## Consequences

Managing the panel needs SSH access. A new 3x-ui version is a deliberate change: new tag, new checksum, and a fresh run of the verify scripts. Subscriptions cannot be offered without revisiting this decision.

## Do not

- Do not open a firewall port for the 3x-ui panel or its subscription service, or bind either to a public address: a reachable panel can be discovered and attacked. (ADR-0002)
