#!/usr/bin/env python3
"""Point the SSH ingress rule at whatever address this machine has today.

SSH to the server is restricted to one IP in the OCI security list. A home
connection's address changes, and when it does `deploy.sh` fails with a
connection timeout that looks exactly like the server being down. It is not.

    python deploy/allow-my-ip.py $(curl -s https://api.ipify.org)/32

⚠️ This uses the OCI **Python SDK**, not the `oci` command-line tool, because
the CLI is not installed on this machine — only ~/.oci/config and the API key
are. `pip install oci` if the import fails.

⚠️ Only the cloud side restricts SSH by address; the host's own iptables allows
port 22 from anywhere. That is deliberate and it is what makes this
recoverable — a host-level IP rule would lock the machine away with no way back
in short of the serial console.
"""

import sys

import oci

# `Default Security List for gasta-vcn`. Hardcoded rather than discovered:
# there is one VCN and one security list, and a script that goes looking is a
# script that can find the wrong one.
SECURITY_LIST_ID = (
    "ocid1.securitylist.oc1.ap-mumbai-1."
    "aaaaaaaat3ok6qfm3c7xz5re2lec7y4z4x43zsqvz52fqhn4hcxby7nthbja"
)

TCP = "6"


def main() -> None:
    if len(sys.argv) != 2 or "/" not in sys.argv[1]:
        sys.exit("usage: allow-my-ip.py <cidr>   e.g. 203.0.113.7/32")
    new_source = sys.argv[1]

    config = oci.config.from_file()
    network = oci.core.VirtualNetworkClient(config)
    security_list = network.get_security_list(SECURITY_LIST_ID).data

    # Found by port, not by position. The rule order in the list is not stable
    # and an index would eventually move the wrong rule — which here means
    # opening something to the internet or locking ourselves out.
    changed = False
    for rule in security_list.ingress_security_rules:
        ports = rule.tcp_options.destination_port_range if rule.tcp_options else None
        if rule.protocol == TCP and ports and ports.min == 22:
            print("ssh: %s -> %s" % (rule.source, new_source))
            rule.source = new_source
            changed = True

    if not changed:
        # Refuses rather than adding one. If the SSH rule is missing, something
        # is different from what this script assumes, and guessing at firewall
        # rules is how a database ends up on the open internet.
        sys.exit("No port-22 ingress rule found. Refusing to guess — check the console.")

    network.update_security_list(
        SECURITY_LIST_ID,
        oci.core.models.UpdateSecurityListDetails(
            # Both lists must be sent: this is a replace, not a merge, and
            # omitting egress would delete every outbound rule.
            ingress_security_rules=security_list.ingress_security_rules,
            egress_security_rules=security_list.egress_security_rules,
        ),
    )
    print("updated; SSH should work within a few seconds")


if __name__ == "__main__":
    main()
