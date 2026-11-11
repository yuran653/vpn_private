# Design: serve-own-cover-site

## Approach

Xray keeps port 443. Its Reality `target` moves from `www.samsung.com:443` to a web server on loopback, and `serverNames` becomes `status.casedigestai.com`. A handshake with the key is the tunnel, as before. Any other handshake, whatever name it carries, is passed to the local web server, which holds the certificate for both names.

```
internet :443 -> Xray (Reality) --key ok--> tunnel -> WARP
                                --no key--> nginx 127.0.0.1:8443 (TLS 1.3, HTTP/2, LE cert)
                                                -> site container 127.0.0.1:8080
internet :80  -> nginx (ACME challenge; everything else 301 to https)
```

- **nginx** (Ubuntu package, on the host): port 80 on the public address; TLS on `127.0.0.1:8443` with TLS 1.3, X25519 and HTTP/2, which Reality requires of its target. `access_log off`, `server_tokens off`. It proxies to the site container.
- **certbot** (Ubuntu package): one certificate for both names by HTTP-01 through a webroot; the packaged `certbot.timer` renews; a deploy hook reloads nginx. The first run needs the A records in place, so the script checks them and stops with a clear message if they don't match the server address.
- **Docker** (`docker.io` and `docker-compose-v2` from Ubuntu): one compose project in `/opt/cover-site` running an `nginx` image, serving `site/html/` read-only, published as `127.0.0.1:8080:80`, logging driver `none`. Docker's default bind address is set to `127.0.0.1`, so a container published without an address is still not public. [TODO-CLARIFY: pin the image by digest; the registry could not be reached from the workstation.] The owner's real website later replaces this service only.
- **Landing page**: `site/html/index.html`, with `site/html/favicon.svg`, with inline CSS, no JavaScript, no external URL. System serif stack for the heading, `prefers-color-scheme` for dark mode.
- **Order in `deploy-vpn.sh`**: install and start nginx on port 80 and the container, obtain the certificate, start TLS on loopback, and only then switch the Reality target. The tunnel is down only for the Xray restart.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| deploy | `scripts/deploy-vpn.sh` | `REALITY_TARGET` replaced by the cover names and the loopback target; new steps for nginx, certbot, Docker and the site; `ufw allow 80/tcp`; inbound update on an existing host. |
| site | `site/html/index.html`, `site/html/favicon.svg`, `site/docker-compose.yml`, `site/nginx.conf` | New: landing page, container definition, the container's web server config. The host web server config is written by `deploy-vpn.sh`, because it differs before and after the certificate exists. The deploy script reads `site/` from next to itself. |
| verify | `scripts/verify-external.sh`, `scripts/verify-vpn.sh` | Checks for R-04, R-05, R-06.b, R-14.c, R-15, R-16. |
| docs | `docs/decisions/INDEX.md`, `docs/censor-red-flags.md`, `docs/vps-access.md` | ADR-0012 row, ADR-0003 superseded, "Do not" line; flags 1, 7, 10 marked fixed; recovery steps now include DNS. |

New modules or dependencies between modules: `site/` is new. `docs/architecture.md` has no modules listed yet ([TODO-CLARIFY] there), so nothing to edit.

## Contracts and data

- The client link changes once (`sni=`). Client ID, public key and short ID are kept (R-vpn-server-14.b).
- New state on the server, never in the repository (C-01): the certificate and its private key in `/etc/letsencrypt`, readable by root.
- Let's Encrypt registration without an email address, so no contact detail is stored with the certificate authority.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| nginx on 443 in front, passing the tunnel to Xray by SNI | Adds a hop to every tunnel connection and changes the ADR-0005 limits; Reality's own fallback already does the split. |
| Xray `xver` (PROXY protocol) so nginx sees probe addresses | Nothing uses the address, and R-vpn-server-06 prefers not to have it. |
| nginx in the same container as the site, holding the certificate | The real website will replace the container; the certificate and port 80 should outlive it. |

Decision record needed: ADR-0012

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-04.a, .b | `scripts/verify-external.sh` (R-vpn-server-04.a, .b) |
| R-vpn-server-04.c | `scripts/verify-vpn.sh` (R-vpn-server-04.c) |
| R-vpn-server-05.a, .c | `scripts/verify-vpn.sh` (R-vpn-server-05.a, .c) |
| R-vpn-server-05.b | `scripts/verify-external.sh` (R-vpn-server-05.b) |
| R-vpn-server-06.b | `scripts/verify-vpn.sh` (R-vpn-server-06.b) |
| R-vpn-server-14.c | `scripts/verify-vpn.sh` (R-vpn-server-14.c) |
| R-vpn-server-15.a, .b, .e | `scripts/verify-external.sh` (R-vpn-server-15.a, .b, .e) |
| R-vpn-server-15.c, .d | `scripts/verify-external.sh` (R-vpn-server-15.c, .d), run against the served page |
| R-vpn-server-16.a, .c | `scripts/verify-vpn.sh` (R-vpn-server-16.a, .c) |
| R-vpn-server-16.b | `scripts/verify-vpn.sh` (R-vpn-server-16.b), `certbot renew --dry-run` |

Every other criterion in the spec is re-run unchanged after the deploy, R-vpn-server-02, -03 and -12 in particular.

## Risks

- **The address is blocked again after the names go live** (2026-11-12 incident). Not containable by this change; see the open questions in the proposal.
- **Docker rewrites iptables** and can bypass ufw for published ports. Contained by publishing on `127.0.0.1` only and by R-vpn-server-05.b from outside.
- **Docker with IPv6 off in the kernel** (ADR-0004). Docker's default bridge is IPv4-only; R-vpn-server-02 is re-run.
- **Let's Encrypt rate limits** on repeated failed issuance. The script issues only when no valid certificate exists, and checks DNS first.
- **nginx on Ubuntu 22.04 and 24.04** (1.18 and 1.24) both take HTTP/2 on the `listen` line; the separate `http2` directive needs 1.25.
- **nginx's packaged default site listens on IPv6**, which the host does not have (ADR-0004), so the package's first start fails. The script holds the start back during the install and removes the default site.
- **Not run yet.** `shellcheck` and Docker are not available on the workstation: the scripts passed `bash -n` only, and the container definition is first exercised on the VPS. The deploy script tests each part before it touches the inbound.
- **Downtime**: about 10 minutes is reserved; the tunnel itself drops only for the Xray restart. Roll back by restoring the previous inbound, which the script saves in `/root/vpn/inbound-previous.json` before changing it.
