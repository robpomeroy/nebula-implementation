# Introduction

This is an Ansible playbook to configure a Nebula lighthouse node. It needs
the "capabilities" module. Install that on your Ansible control node with:

    ansible-galaxy collection install community.general

The Nebula service runs under an unprivileged user account. The `nebula` binary
is granted the capability to create and manage a network interface.

# Configuration

Amend `inventory`, `ansible.cfg`, `group_vars\all.yml` and `remote_user` in
`main.yml`, to suit your use. You may also wish to amend the lighthouse
configuration file at `roles\nebula-lighthouse\templates\lighthouse.yaml.j2`.

# Nebula binary

The Linux x64 binary is stored at `roles\nebula-lighthouse\files\nebula_1.4`
and copied to the remote node, in the associated task. Feel free to adopt a
different approach! You probably should check the hash of this file rather than
trusting me.

# Certificates

Having generated a key pair for your lighthouse, place these files (`node.crt`
and `node.key`) at `roles\nebula-lighthouse\files\`. You should as a matter of
good practice **encrypt the private key (node.key) using Ansible Vault**. Then
provide the decryption key when running your play.

Place your CA public certificate in the same directory.

# Playbook runs

Assuming the Ansible Vault password is stored at `~/vault-password-file`, run:

    ansible-playbook --vault-password-file=~/vault-password main.yml

# DNS

I have not been able to get Nebula's built-in DNS working remotely - only on the
Lighthouse node (which isn't that useful). Could be because of needing to use a
non-standard port (on my machine, systemd is already using port 53); could be
something else. It's not well documented, so I rely on IP addresses for now.