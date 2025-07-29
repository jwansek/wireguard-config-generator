#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

# public network interface
# usually the same, unless using tunnel
IPV4_INTERFACE=

# name for the wireguard interface
WG_INTERFACE=wg0

# the server's domain name or ip address
WG_SERVER_ADDRESS=

# number of client configs to generate
# must < 254
WG_CLIENT_NO=3

# DNS server for clients
DNS=1.1.1.1


# remove previously generated configs and make room for new ones
rm -vrf wgconfigs
mkdir wgconfigs

echo generating server config
# generate the [Interface] part for the server
WG_IPV4_PREFIX=10.13.37
WG_SERVER_PORT=51820

WG_SERVER_PRIVATE_KEY=$(wg genkey)
WG_SERVER_PUBLIC_KEY=$(echo "$WG_SERVER_PRIVATE_KEY" | wg pubkey)

cat > wgconfigs/${WG_INTERFACE}.conf << EOF 
[Interface]
Address = ${WG_IPV4_PREFIX}1/24
ListenPort = ${WG_SERVER_PORT}
PrivateKey = ${WG_SERVER_PRIVATE_KEY}
EOF

# generate client configs
CLIENT_IP_SUFFIX=2
mkdir -p wgconfigs/clientconfigs
while [ $CLIENT_IP_SUFFIX -le $[$WG_CLIENT_NO+1] ]
do
echo generating client config w/ IP ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}

WG_CLIENT_PRIVATE_KEY=$(wg genkey)
WG_CLIENT_PUBLIC_KEY=$(echo "$WG_CLIENT_PRIVATE_KEY" | wg pubkey)
WG_CLIENT_PSK=$(wg genpsk)

cat > wgconfigs/clientconfigs/${WG_INTERFACE}c${CLIENT_IP_SUFFIX}.conf << EOF 
[Interface]
Address = ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}/32
PrivateKey = ${WG_CLIENT_PRIVATE_KEY}
DNS = ${DNS}

[Peer]
PublicKey = ${WG_SERVER_PUBLIC_KEY}
PresharedKey = ${WG_CLIENT_PSK}
Endpoint = ${WG_SERVER_ADDRESS}:${WG_SERVER_PORT}
AllowedIPs = 0.0.0.0/0
EOF

# add a peer to server config
cat >> wgconfigs/${WG_INTERFACE}.conf << EOF 

[Peer]
PublicKey = ${WG_CLIENT_PUBLIC_KEY}
PresharedKey = ${WG_CLIENT_PSK}
AllowedIPs = ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}/32
EOF

CLIENT_IP_SUFFIX=$[$CLIENT_IP_SUFFIX+1]
done

exit 0
