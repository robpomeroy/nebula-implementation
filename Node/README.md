# Introduction

These are PowerShell scripts, intended to ease the implementation of Nebula on
a Windows node (as a participating node, not as a lighthouse). They're a bit
rough-and-ready. Polishing is left as an exercise for the reader. They work for
me!

# Usage

Amend the SETTINGS section in the PowerShell scripts, to suit your needs.
Generate key pairs using `New-KeyPair.ps1` (you'll need the CA public and
private certificates to hand) and install Nebula using... you guessed it,
`Install-Nebula.ps1`.
