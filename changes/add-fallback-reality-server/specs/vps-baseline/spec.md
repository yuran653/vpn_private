# Delta: vps-baseline

## ADDED

### R-vps-baseline-08: SSH from listed addresses only, on request

When the operator asks for it, the SSH port answers only the addresses the operator lists; without the request the baseline behaves as before.

- **R-vps-baseline-08.a** WHEN the script runs with the restriction and a list of IPv4 addresses THEN the firewall admits the SSH port from those addresses only, and the rule that admitted everyone is gone.
- **R-vps-baseline-08.b** WHEN the script runs with the restriction and the address of the SSH session that runs it is not on the list THEN it exits with an error before changing the firewall.
- **R-vps-baseline-08.c** WHEN the script runs without the restriction THEN the SSH port is admitted from anywhere, as R-vps-baseline-03.a states.
- **R-vps-baseline-08.d** WHEN the script runs again with a different list THEN the firewall admits exactly the new list.
