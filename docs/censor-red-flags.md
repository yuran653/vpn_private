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
| 4 | Many users on one IP **Deferred 2026-11-12** | Once there are several users, many unrelated home addresses in one country all connect to the same VPS. That marks a proxy without looking inside the traffic. Weaker since ADR-0013: they connect to Cloudflare addresses, but they all name one hostname. Deferred by the owner for the test period, which has at most 20 to 30 users across the three countries: the Cloudflare addresses are shared with millions of sites, so the user count does not stand out there. The name does; on Beeline it was cut with one user (see "Field observation" below). Revisit when users grow past the test period. | CN, RU, IR |
| 5 | SSH is open on the same IP | `harden-vps.sh` allows the SSH port to everyone. The OpenSSH banner shows the Ubuntu version, so a probe sees a Linux VPS next to the website. | CN (active probing) |

## Medium: makes detection easier

| # | Flag | What the censor sees | Who checks it |
|---|---|---|---|
| 6 | Only one transport, with no fallback | XHTTP through Cloudflare is the only way in today (ADR-0013); a fallback server reached directly is decided but not built (ADR-0018); before, it was Reality over TCP 443. Once the IP or protocol is blocked, every user is cut off at once. Iran's protocol whitelisting and Russia's whitelist mode during shutdowns block it outright. On 2026-11-12 a Russian mobile network hung HTTP/2 to all three site names while HTTP/1.1 passed; the link now offers HTTP/1.1 only (ADR-0015). | CN, RU, IR |
| 7 | ~~Probe timing gives the relay away~~ **Fixed 2026-11-12** | Was: a probe without the key was relayed to the real samsung.com, a round trip away. Now the server answers the probe itself, from a web server on the same host (ADR-0012). | CN |
| 8 | The fingerprint may not match the device | The client link always sets one fingerprint, since ADR-0015 `fp=android` (it was `chrome`; the browser ones offer `h2` and break the HTTP/1.1 link), even from an iPhone, where real browsers send Safari's hello. And uTLS's Chrome fingerprint can fall behind the current Chrome release. | CN |
| 9 | No HTTP/3 | Was: the server answered TLS over TCP only. Cloudflare's edge now answers the site names over HTTP/3 too, for browsers; the tunnel itself uses HTTP/1.1 (ADR-0015). | CN |
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
| Recovery | A new IP from Z.com, then a re-run of `deploy-vpn.sh` to rewrite the client link, which named the address at the time. Since ADR-0013 the link names the host and does not change with the address (`docs/vps-access.md`, "What the server does not defend against"). |

[TODO-CLARIFY: which ISP and country blocked the IP, and was the domain used in the client link, in DNS only, or on a certificate?]

Lessons:

- Do not link a domain to the VPS IP without a decision record. ADR-0012 was that record for `casedigestai.com`. Since ADR-0018 the owner's domain is never pointed straight at a VPS address, with or without a record.
- The cover name that matches the IP was deployed on 2026-11-12 on the live IP, not on a spare one. The VPN worked on Wi-Fi and mobile data afterwards. If the IP is blocked again, the domain link is the first suspect.
- With one IP and one transport (flag 6) a block cuts every user off at once, so spare IPs are not optional.

## Where fixes would start

Flags 1 and 2 are fixed (ADR-0012, ADR-0013). Fixing flags 5 and 6 would cover most of the remaining risk. Options mentioned so far, none decided:
- SSH reachable only from known addresses, or only through a hidden path.
- A second transport and spare IPs, so one block doesn't cut everyone off. Decided as ADR-0018 (accepted 2026-11-12, not built yet).

Order chosen by the owner on 2026-11-12. Step 1 is decided (ADR-0018); the others still need their own decision:

1. A second transport: direct Reality on a separate VPS and address, with the Cloudflare path kept as the first one (ADR-0018).
2. SSH closed to all but known addresses before that server goes up (flag 5).
3. Spare domains on different registered domains, vetted with `scripts/check-name.sh` and kept unused.
4. For Russia an entry relay inside the country; for China a host with a better route.

Decided on 2026-11-12 and written, not yet run on a server (`changes/protect-the-name/`): the tunnel on Cloudflare's other HTTPS ports (ADR-0020, a second way in for flag 6 when a network cuts 443 but not the name), and ECH off, hello fragmentation in the link, split tunneling for every user and a word rule for names (ADR-0021, for flag 3 and the life of a name).

Expected users: at most 20 to 30 during the test period (owner, 2026-11-12).

[TODO-CLARIFY: which countries come first?]

## Field observation: Beeline, Moscow, mobile data (2026-11-12)

Measured from a phone (Termux, no VPN) after the key failed in Happ with the HTTP/1.1 link (ADR-0015). Each line is a test and its result.

| Test | Result |
|---|---|
| GET over HTTP/1.1 to the three site names | 200 |
| GET over HTTP/2 to the three site names | hangs after the TLS handshake |
| HTTP/2 and large downloads from other Cloudflare names | work |
| POST to `files.casedigestai.com` over HTTP/1.1 | 10 and 500 bytes pass; 2000 bytes and up hang |
| POST to `casedigestai.com` and `status.casedigestai.com`, 5 KB | hang |
| POST to `www.cloudflare.com`, 2 KB to 30 KB | pass |
| `www.cloudflare.com` name sent to our Cloudflare address, 10 KB POST | passes |
| Our name sent to `www.cloudflare.com`'s address, 10 KB POST | hangs |

Reading: the carrier cuts uploads of more than about 1 to 2 KB to any name under `casedigestai.com`, and the address does not matter. The tunnel needs uploads, so the key cannot connect on this network, whatever the transport settings. The cut follows the name, so a new domain is the first thing to try; whether a fresh name stays unflagged once it carries tunnel traffic is not known. Globalping probes on MTS, Rostelecom and Russian datacenter networks loaded the pages over HTTPS, but they ran GET requests only; uploads were not tested there, so it is not known whether other carriers cut them too.

The domain is listed in `docs/blocked-names.txt`. A name is tried with `scripts/check-name.sh` from a phone on mobile data before it carries the tunnel (ADR-0017).

## Assessment by country (2026-11-12)

How the setup of ADR-0013 to ADR-0015 stands against each censor. Only the Russian row rests on our own measurements (the field observation above). The rest is general knowledge of each censor up to mid-2026, not tested from inside the country and not checked against current reports.

What holds everywhere: a probe of the name gets a real site with a valid certificate; the server's own address answers only Cloudflare on 80 and 443, so blocking or probing that address does nothing; the wire shows ordinary TLS to Cloudflare, not VLESS. The weak point everywhere is flag 6: one domain, on one network, with one transport.

| Country | Methods | Does the setup survive? |
|---|---|---|
| Russia (TSPU) | Filtering by the name in the TLS hello; throttling of Cloudflare and foreign hosting ranges since 2025; Cloudflare's encrypted hello (ECH) blocked; signatures for OpenVPN and WireGuard; whitelist-only mode on mobile networks during shutdowns. | No. Measured: Beeline cut uploads to every name under the domain. A new domain may work for a while. Nothing foreign works in whitelist mode. |
| Iran | Name filtering and DNS poisoning; unknown protocols throttled, only DNS, HTTP and HTTPS pass freely; foreign hosting addresses blocked; some Cloudflare addresses throttled per ISP; TLS fingerprint filtering; national-intranet mode during shutdowns. | Probably, in normal times: a tunnel behind Cloudflare is among the most used methods there. Expect it to differ by ISP and to fail in a shutdown. |
| China (GFW) | Name filtering with injected resets and DNS poisoning; IP blocking; active probing; detection of TLS inside TLS; encrypted SNI blocked; heavier blocking around sensitive dates. | Poorly. The free Cloudflare plan has no nodes in China, so the path is long and many Cloudflare addresses are throttled. A name with steady heavy traffic tends to be blocked. Probing is not the risk. |

Hardening by country, none decided:

- **Russia:** a second transport off Cloudflare (ADR-0018); an entry relay on a VPS inside Russia that forwards to this server, the only design with a chance in whitelist mode; spare domains on different registered domains, since all names under one domain were cut together.
- **Iran:** let a user put a Cloudflare address that works on their ISP into the link, with host and name unchanged; hello fragmentation in the client (`fragment` in Xray); the other ports Cloudflare proxies (2053, 2083, 2087, 2096, 8443), which today's nginx and firewall do not open.
- **China:** a direct transport on a host with a good route to China, which matters more than any obfuscation and which Thailand usually is not; a QUIC transport with port hopping as a further option, though UDP is often rate-limited; per-user names (flag 4).

Also open:

- Domain fronting is not available: Cloudflare refuses a request whose TLS name and Host header belong to different zones. Reality, which borrows a large site's name, is the practical replacement.
- The link sends `fp=android` even from an iPhone (flag 8).
- Cloudflare's free plan is not meant for proxying bulk non-web traffic; the account can be closed. [TODO-CLARIFY: check the current Cloudflare terms for this use.]
