# Nebula implementation

## Introduction

[Nebula](https://github.com/slackhq/nebula) (from Slack) creates a mesh network
that overlays any other network. Nodes on this network can be on separate
physical networks, including behind NAT, and still communicate with each other
through Nebula.

Nebula requires one node to be discoverable on the internet - the "lighthouse".
All other nodes use the lighthouse to register with the network. Nodes do not
route to each other via the lighthouse, however. They negotiate the shortest
path, be that through UDP punching, or via the LAN (if on the same LAN).

Nodes can be assigned to one or more security group, and these groups are used
to create firewall rules permitting or denying traffic between nodes as the
case may be.

## This repository

This repo contains an Ansible playbook for setting up a Nebula lighthouse,
and PowerShell helper scripts for deployment under Windows.

## Certificate Authority

Each Nebula network depends on creation of a single certificate authority key
pair. This can be generated on any computer that has access to the
`nebula-cert` binary:

    nebula-cert ca -name "Office primary" -duration "8760h" -out-crt 2021_office_ca.crt -out-key 2021_office_ca.key
    
This creates the CA public key `2021_office_ca.crt` and the highly sensitive CA
private key `2021_office_ca.key`. Store the private key securely (e.g. in a
password manager) and keep it offline when not needed.

The CA public key is needed by the Ansible playbook that provisions the
lighthouse. The default duration of the CA key pair is 365 days – this can be
overridden with the `-duration` flag on creation though it's best not to
lengthen the lifespan. Instead, plan for future certificate renewal (and make
a note in your calendar!).

**The certificate pair is only required for signing certificates for nodes, so
it does not need to reside (e.g.) on the lighthouse.**

## IP address schema

Design your IP address schema before you implement your Nebula network. This
cannot easily be changed once you're underway. Choose a private network range
that's unlikely to clash with anything in your environment. If you travel and
want to use Nebula from (e.g.) hotel WiFi, use your psychic powers to determine
what IP addresses to avoid. You might try, e.g., 192.168.92.0/22, to give you
a maximum of 1022 nodes.

## Lighthouse playbook

The Ansible playbook can run against most Debian- or Red Hat-derived instances.
The lighthouse requires very few resources, so you can use a tiny cloud instance
or potentially add as an additional capability of some other server, with
minimal impact. The lighthouse simply requires a public IP, with a reachable
UDP port.

Refer to the playbook README for more information.

## Windows nodes

The `Install-Nebula.ps1` PowerShell script sets up a Windows computer ready to
run Nebula. After running the script, it is necessary to place the three
certificate files in the correct location (see Certificates section below) and
then start the Nebula Network Service.

The PowerShell script generates a standard configuration file, which allows ping
from anywhere, and RDP from the user's defined group. For any other
requirements, manually edit the text-based configuration file the script stores
at `C:\Users\[username]\AppData\Roaming\Nebula\node.yaml`.

The script also installs a required TAP driver (a Windows driver for virtual
networks from the OpenVPN project) and assigns the "Private" profile to this
adapter once installed, modifying the relevant registry key under
`Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\`.

##	Android/iOS nodes

Apps for Android and iOS devices are available on the respective app stores.
Certificate installation and generation is somewhat manual, at the time of
writing.

##	Certificates

The security of Nebula is based on certificates. Each node requires its own
public/private key pair, based on the Nebula network's certificate authority.
Node certificates encode (amongst other things) the node's name and unique IP
address within the overlay network. Hence, the name and IP can only be changed
by generating new certificates.

Certificates also contain the security groups to which the node belongs. These
groups are used within firewall rules.

###	Lighthouse, desktops and servers

The `New-KeyPair.ps1` PowerShell script takes some of the work out of generating
new certificates for Windows nodes. It creates the certificates and bundles them
up in a zip file with the root CA public certificate.

###	Mobile devices

The mobile apps do not yet have an automated workflow for configuration. Set up
a new static host in the app, referring to the lighthouse.
 
When using a mobile app, the Nebula app generates a keypair. First transmit the
CA public key to the app (e.g. via email and copy and paste). Once that is
loaded, the app can generate a public key.
 
Pass this public key to `nebula-cert` with the `-in-pub` flag. You will need
the CA public and private certificates available for this. E.g.:

    .\ nebula-cert sign -ca-crt 2021_office_ca.crt -ca-key 2021_office_ca.key -name "My-iPhone" -ip "192.168.93.5/22" -in-pub from-the-app.crt -groups fred

Send the generated certificate back to the app and paste into the "Certificate
PEM Contents" section.

## Support

Please feel free to fork and submit pull requests. Due to "life", I regret I am
unable to provide support using this repo or Nebula in general.