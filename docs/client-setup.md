# Client setup

What every user sets in the client app (Happ) after importing the link. The server cannot enforce any of this (ADR-0021). The menu names below are from Happ's documentation and a third-party guide, not checked on a device. [TODO-CLARIFY: walk through these steps on an iPhone and an Android phone and correct the menu names.]

## 1. Import the link

Import the link you were given. Do not forward it and do not post it anywhere: a name that becomes public is blocked sooner.

## 2. Split tunneling

Send only what needs the tunnel through it. Less traffic on the name makes it stand out less, and local sites work faster.

In Happ this is a routing profile, under Settings, Routing rules. Two ways to set it, the first is the simpler:

| Rule | What goes through the tunnel | What goes direct |
|---|---|---|
| Local sites direct | Everything else | Sites and addresses of your own country (for example `geosite:category-ru` and `geoip:ru`, or `cn`, or `ir`), and private addresses |
| Only blocked sites through the tunnel | The sites you list | Everything else |

Know what this means: a site reached directly sees your real address, and your ISP sees that you visited it, the same as without a VPN. If you want everything hidden, leave split tunneling off.

[TODO-CLARIFY: is one ready-made routing profile per country to be handed out with the link, and in which form does Happ import it?]

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
