# Client setup

What every user sets in the client app (Happ) after importing the link. The server cannot enforce any of this (ADR-0021). The menu names below are from Happ's documentation and a third-party guide, not checked on a device. [TODO-CLARIFY: walk through these steps on an iPhone and an Android phone and correct the menu names.]

## 1. Import the link

Import the link you were given. Do not forward it and do not post it anywhere: a name that becomes public is blocked sooner.

## 2. Split tunneling

Send only what needs the tunnel through it. Less traffic on the name makes it stand out less, and local sites work faster. The recommended scheme also limits what foreign intermediaries (the CDN, the hosting provider, the WARP exit) can learn: Russian destinations stay inside Russia and are never visible to them.

### The recommended scheme

Rules are evaluated top to bottom, first match wins:

| Order | Rule | Action |
|---|---|---|
| 1 | Private and local addresses | Direct |
| 2 | `geosite:category-ru` (Russian sites) | Direct |
| 3 | `geoip:ru` (Russian addresses, when no domain rule matched) | Direct |
| 4 | Everything else (default) | Tunnel |

The category lists are maintained upstream and ship with the app and its core; nobody writes address lists by hand. A specific service that must always appear from the tunnel country gets an explicit domain rule above the default (for example a `geosite:google` rule), but the default already covers everything non-Russian.

The alternative scheme, "only the listed sites through the tunnel", inverts the default: the listed services go through the tunnel, everything else is direct. It sends even less traffic through the tunnel, at the cost of maintaining the list.

Know what this means: a site reached directly sees your real address, and your ISP sees that you visited it, the same as without a VPN. A Russian service you want to hide the visit to is an explicit exception that goes through the tunnel. If you want everything hidden, leave split tunneling off.

### DNS follows the route

Routing rules alone are not enough. If every DNS query goes to the server's resolver, the foreign exit sees the Russian names you visit even when their traffic goes direct. The DNS rules must match the routing rules:

| Query for | Resolved by |
|---|---|
| `geosite:category-ru` and private names | A local resolver (the ISP's, or a local encrypted resolver) |
| Everything else | The server, through the tunnel (DNS-over-HTTPS there) |

### Getting the rules without typing them

The rules are handed out with the link as a ready-made Happ routing profile, not typed by the user:

- A **routing deeplink**: `happ://routing/onadd/{base64}` carries the whole profile in the link itself. Opening it adds and activates the profile; a later link with the same profile name replaces it, which is how updated rules are handed out.
- A **file**: Happ imports routing configs from `.json` and `.happ` files.

So a user receives two artifacts: the `vless://` link and the routing deeplink (or file). No subscription and no public address is involved, so ADR-0011 is unaffected. The profile's DNS fields carry the DNS split above.

Do not distribute a full Xray JSON config instead: Happ passes such a config to the core as-is, and its own routing profiles and interface settings then do not apply. The supported carrier is the link plus the Happ routing profile.

[TODO-CLARIFY: verify on an iPhone and an Android phone that the deeplink and the file import apply the profile, and that the DNS fields behave as described.]

## 3. Hello fragmentation

The link already asks the app to send the TLS hello in pieces (`fragment=1-10,5-20,tlshello`). It applies only while the app's own global fragmentation setting is off, because the app's setting wins over the link's.

- Leave the app's global fragmentation setting off, so the link's values are used.
- If the link does not connect on your network, turn fragmentation on in the app with the same values, or try without it, and tell the owner which one worked.

## 4. Encrypted hello (ECH)

Leave it off. The link carries no ECH setting, and nothing in the app should add one: Cloudflare's ECH is blocked in Russia and encrypted server names are blocked in China.

## 5. When the link stops connecting

Try in this order, and tell the owner what worked:

1. Another network (Wi-Fi instead of mobile data, or the other way round), to see whether the network is the cause.
2. A link for another port. The owner has one for each of 2053, 2083, 2087, 2096 and 8443 (ADR-0020).
3. In Iran: a Cloudflare address that works on your ISP, put in the link's address field, with the host and server name left as they are.
4. The fallback profile, if you were given one (ADR-0018).
