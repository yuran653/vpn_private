# Delta: vpn-server

## MODIFIED

### R-vpn-server-05: Panel not discoverable

The management panel, its subscription service, the tunnel inbound and the site's content server cannot be found or reached from the internet.

- **R-vpn-server-05.a** WHEN the host's listening sockets are listed THEN only SSH, port 80, port 443 and the alternative ports 2053, 2083, 2087, 2096 and 8443 listen on a public address, apart from the UDP socket the proxy holds open to send its WARP tunnel traffic.
- **R-vpn-server-05.b** WHEN a host on the internet connects to the panel port, to the usual panel and subscription ports, or to the ports the tunnel inbound, the web server and the site container use on loopback, THEN the connection is not accepted.
- **R-vpn-server-05.c** WHEN the firewall rules are listed THEN incoming traffic is denied except SSH from anywhere and 80/tcp, 443/tcp and the alternative ports from Cloudflare's published IPv4 ranges only.

## ADDED

### R-vpn-server-23: Alternative ports

The site and the tunnel answer on Cloudflare's other HTTPS ports, 2053, 2083, 2087, 2096 and 8443, as they do on 443, and only through Cloudflare.

- **R-vpn-server-23.a** WHEN a browser opens `https://` on the tunnel name with any of the alternative ports THEN it receives a publicly trusted certificate and the landing page.
- **R-vpn-server-23.b** WHEN a client connects with the link for any alternative port and requests a web page THEN the page sees an IPv4 client address that is not the server's.
- **R-vpn-server-23.c** WHEN a host outside Cloudflare's ranges connects to an alternative port of the server's own address THEN it gets no answer.
- **R-vpn-server-23.d** WHEN the links for the alternative ports are read THEN there is one per port, in a file readable by root only, and each differs from the main link in the port and the profile name only.

### R-vpn-server-24: No encrypted hello

Neither a client using a link nor a browser opening the site is led to send an encrypted hello (ECH).

- **R-vpn-server-24.a** WHEN any client link is read THEN it carries no ECH setting.
- **R-vpn-server-24.b** WHEN the HTTPS records of the site names are read from DNS THEN none offers an ECH configuration.

### R-vpn-server-25: No avoided word in a name

No site name contains a word that says what the service is or that draws political attention.

- **R-vpn-server-25.a** WHEN the site names are compared with `docs/avoided-name-words.txt` THEN no name contains a listed word.

### R-vpn-server-26: The link asks for hello fragmentation

The owner's links ask the client app to send the TLS hello in pieces.

- **R-vpn-server-26.a** WHEN the main link or a link for an alternative port is read THEN it carries a fragmentation setting that applies to the TLS hello.
- **R-vpn-server-26.b** WHEN a client app that honours the setting connects THEN the TLS hello leaves the device in more than one packet.

### R-vpn-server-27: Users are told the client settings

Each user receives the client setup guide with the link.

- **R-vpn-server-27.a** WHEN a link is handed to a user THEN the user also gets `docs/client-setup.md`: split tunneling, fragmentation, ECH off, and what to try when the link stops connecting.
