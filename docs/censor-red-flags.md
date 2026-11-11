# Red flags for censors

What the deployed server gives away to the censors in China (GFW), Iran and Russia (TSPU). Checked against `scripts/deploy-vpn.sh` and `scripts/harden-vps.sh` on 2026-11-11.

Goal, as stated by the owner on 2026-11-11: a robust, stable and safe VPN for users in China, Iran and Russia. This is wider than the personal Thai VPS that `AGENTS.md` describes, and the server has one client (`owner`) today.

[TODO-CLARIFY: should `AGENTS.md` and `docs/constitution.md` be restated for the multi-user, three-country goal?]

Each flag is a finding, not a fix. A fix is its own change with a decision record.

## High: likely to get the server IP blocked

| # | Flag | What the censor sees | Who checks it |
|---|---|---|---|
| 1 | The name and the IP don't match | The TLS hello names `www.samsung.com` (`REALITY_TARGET`), but the IP belongs to Z.com, a Thai hosting provider. Its IP owner (ASN) and reverse DNS show it isn't Samsung. | CN, RU, IR |
| 2 | The IP is in a datacenter | Home users sending gigabytes to a hosting provider's IP block: the basic proxy pattern. Russia is reported to throttle TLS to foreign hosting networks after the first few kilobytes. | RU, CN |
| 3 | One IP, heavy traffic, long sessions | Each user holds connections for hours and moves gigabytes to one "website". | CN, RU |
| 4 | Many users on one IP | Once there are several users, many unrelated home addresses in one country all connect to the same VPS. That marks a proxy without looking inside the traffic. | CN, RU, IR |
| 5 | SSH is open on the same IP | `harden-vps.sh` allows the SSH port to everyone. The OpenSSH banner shows the Ubuntu version, so a probe sees a Linux VPS, not Samsung's front end. | CN (active probing) |

## Medium: makes detection easier

| # | Flag | What the censor sees | Who checks it |
|---|---|---|---|
| 6 | Only one transport, with no fallback | Reality over TCP 443 is the only way in. Once the IP or protocol is blocked, every user is cut off at once. Iran's protocol whitelisting and Russia's whitelist mode during shutdowns block it outright. | CN, RU, IR |
| 7 | Probe timing gives the relay away | When a probe fails the check, Reality relays it to the real samsung.com. That adds a round trip from Thailand to Samsung, so the TLS reply arrives late compared with the TCP handshake. | CN |
| 8 | The fingerprint may not match the device | The client link always sets `fp=chrome`, even from an iPhone, where real browsers send Safari's hello. And uTLS's Chrome fingerprint can fall behind the current Chrome release. | CN |
| 9 | No HTTP/3 | Chrome visiting the real samsung.com would also use QUIC/HTTP/3. This server only answers TLS over TCP. A weak signal. | CN |
| 10 | The cover site doesn't fit Chinese users | In China, samsung.com is served from local CDN nodes. A Chinese user reaching it through a Thai IP is unusual. | CN |

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

- Do not link a domain to the VPS IP without a decision record. A name next to the IP adds to flag 1.
- The "cover name that matches the IP" option below has the same risk. Test it on a spare IP first.
- With one IP and one transport (flag 6) a block cuts every user off at once, so spare IPs are not optional.

## Where fixes would start

Fixing flags 1, 2, 5 and 6 would cover most of the risk. Options mentioned so far, none decided:

- A cover name that matches the IP: an owned domain with a real certificate on the VPS. The 2026-11-12 incident followed a domain link, so treat this with care.
- Traffic through a CDN (VLESS over XHTTP or WebSocket behind Cloudflare), which hides the VPS IP.
- SSH reachable only from known addresses, or only through a hidden path.
- A second transport and spare IPs, so one block doesn't cut everyone off.

[TODO-CLARIFY: which countries come first, and how many users are expected?]
