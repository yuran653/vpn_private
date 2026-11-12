# Red flags for censors

What the deployed server gives away to the censors in China (GFW), Iran and Russia (TSPU). Checked against `scripts/deploy-vpn.sh` and `scripts/harden-vps.sh` on 2026-11-11. Flags 1, 7 and 10 were fixed on 2026-11-12 by serving the owner's own site as the cover site (ADR-0012). Flag 2 was fixed by routing every client through Cloudflare (ADR-0013); that also weakens flags 3, 4 and 9. Flag 3 was weakened further by connection rotation and a cover name for heavy traffic (ADR-0014). The other flags stand.

Goal, as stated by the owner on 2026-11-11: a robust, stable and safe VPN for users in China, Iran and Russia. This is wider than the personal Thai VPS that `AGENTS.md` describes, and the server has one client (`owner`) today.

[TODO-CLARIFY: should `AGENTS.md` and `docs/constitution.md` be restated for the multi-user, three-country goal?]

Each flag is a finding, not a fix. A fix is its own change with a decision record.

## High: likely to get the server IP blocked

| # | Flag | What the censor sees | Who checks it |
|---|---|---|---|
| 1 | ~~The name and the IP don't match~~ **Fixed 2026-11-12** | Was: the TLS hello named `www.samsung.com` on a Thai hosting IP. Then the hello named `status.casedigestai.com`, which resolved to this IP (ADR-0012). Now the same name resolves to Cloudflare, which is where the client connects (ADR-0013). | CN, RU, IR |
| 2 | ~~The IP is in a datacenter~~ **Fixed 2026-11-12** | Was: home users sending gigabytes to a hosting provider's IP block, the basic proxy pattern. Now clients connect only to Cloudflare addresses, which serve millions of ordinary sites; the server's own address answers nobody but Cloudflare on 80 and 443 (ADR-0013). New risk instead: Russia is reported to throttle Cloudflare since 2025, and the free plan has no nodes in China. | RU, CN |
| 3 | One IP, heavy traffic, long sessions **Weakened 2026-11-12** | Was: each user held connections for hours and moved gigabytes to one "website". Since ADR-0013 the address is Cloudflare's, shared with many sites. Since ADR-0014 a connection takes no new sessions after 2 to 5 minutes, requests and responses are padded, and the name is `files.casedigestai.com`, a case-file sync service where heavy transfers both ways are normal. Left: one hostname still carries all of a user's traffic, and a heavy user is still heavy. Next measures: split tunneling in the client, per-user names. | CN, RU |
| 4 | Many users on one IP | Once there are several users, many unrelated home addresses in one country all connect to the same VPS. That marks a proxy without looking inside the traffic. Weaker since ADR-0013: they connect to Cloudflare addresses, but they all name one hostname. | CN, RU, IR |
| 5 | SSH is open on the same IP | `harden-vps.sh` allows the SSH port to everyone. The OpenSSH banner shows the Ubuntu version, so a probe sees a Linux VPS next to the website. | CN (active probing) |

## Medium: makes detection easier

| # | Flag | What the censor sees | Who checks it |
|---|---|---|---|
| 6 | Only one transport, with no fallback | XHTTP through Cloudflare is the only way in (ADR-0013); before, it was Reality over TCP 443. Once the IP or protocol is blocked, every user is cut off at once. Iran's protocol whitelisting and Russia's whitelist mode during shutdowns block it outright. On 2026-11-12 a Russian mobile network hung HTTP/2 to all three site names while HTTP/1.1 passed; the link now offers HTTP/1.1 only (ADR-0015). | CN, RU, IR |
| 7 | ~~Probe timing gives the relay away~~ **Fixed 2026-11-12** | Was: a probe without the key was relayed to the real samsung.com, a round trip away. Now the server answers the probe itself, from a web server on the same host (ADR-0012). | CN |
| 8 | The fingerprint may not match the device | The client link always sets one fingerprint, since ADR-0015 `fp=android` (it was `chrome`; the browser ones offer `h2` and break the HTTP/1.1 link), even from an iPhone, where real browsers send Safari's hello. And uTLS's Chrome fingerprint can fall behind the current Chrome release. | CN |
| 9 | No HTTP/3 | Was: the server answered TLS over TCP only. Cloudflare's edge now answers the site names over HTTP/3 too, for browsers; the tunnel itself still uses HTTP/2. | CN |
| 10 | ~~The cover site doesn't fit Chinese users~~ **Fixed 2026-11-12** | Was: samsung.com reached through a Thai IP, while China serves it from local CDN nodes. Now the name is a small site that is hosted only on this IP (ADR-0012). | CN |

## Not a flag on the wire (already handled)

- **WARP exit:** the WireGuard tunnel to Cloudflare runs between the VPS and Cloudflare, so the user's ISP never sees it.
- **DNS and IPv6:** DNS leaks and IPv6 egress are closed on the server (`specs/vpn-server/spec.md`).
- **Panel:** 3x-ui listens on loopback only and can't be found from outside.

## Incident: the IP was blocked after a domain was linked (2026-11-12)

A user could not connect. The server itself was healthy; its address was no longer reachable from the user's ISP.

| What | Finding |
|---|---|
| When | 2026-11-12, right after a domain was linked to the server IP. |
| Symptom | `ping`, SSH (22) and HTTPS (443) to the server IP time out from the user's network and from the owner's Mac. |
| Server | Up, with enough memory and disk. `ssh`, `x-ui`, `fail2ban` and `ufw` active, 22 and 443 listening, VPS network fine (it reaches `1.1.1.1`). A packet capture showed the server answering other clients on 443 and 22. |
| Rules out | A server fault, a firewall rule or ban on the server (only one unrelated address was banned by `fail2ban`), and a ufw limit. The owner's manual restart did not change anything. |
| Cause | The ISP block of the server IP. Not proven: the capture of the owner's own packets and a test from a second network were not done. The timing points at the domain link (flag 1: a name now ties the Thai hosting IP to a hostname that DNS and certificates expose). |
| Recovery | A new IP from Z.com, then a re-run of `deploy-vpn.sh` to rewrite the client link (`docs/vps-access.md`, "What the server does not defend against"). |

[TODO-CLARIFY: which ISP and country blocked the IP, and was the domain used in the client link, in DNS only, or on a certificate?]

Lessons:

- Do not link a domain to the VPS IP without a decision record. ADR-0012 is that record for `casedigestai.com`.
- The cover name that matches the IP was deployed on 2026-11-12 on the live IP, not on a spare one. The VPN worked on Wi-Fi and mobile data afterwards. If the IP is blocked again, the domain link is the first suspect.
- With one IP and one transport (flag 6) a block cuts every user off at once, so spare IPs are not optional.

## Where fixes would start

Flags 1 and 2 are fixed (ADR-0012, ADR-0013). Fixing flags 5 and 6 would cover most of the remaining risk. Options mentioned so far, none decided:
- SSH reachable only from known addresses, or only through a hidden path.
- A second transport and spare IPs, so one block doesn't cut everyone off.

[TODO-CLARIFY: which countries come first, and how many users are expected?]
