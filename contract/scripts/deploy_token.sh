#!/bin/bash -e

# URL of the ethereum RPC node to use. Choose this based on your target network
# (e.g., this deploys to goerli optimism testnet)
# RPC_URL=https://goerli.optimism.io
# RPC_URL=https://rpc-mumbai.maticvigil.com
RPC_URL=https://rpc.ankr.com/polygon_mumbai

# Private key of deployer account
DEPLOYER_PRIVATE_KEY="b29c95306899b54f317f3e534e0ba5899435414c1bcfa7bcafee68ddf25f81ee"

ETHERSCAN_API_KEY="TCXB1BR4188DIYH6GFDEYGP3F3S9QRNVPY"

# Note the -l here uses a ledger wallet to deploy your contract. You may need to change this
# option if you are using a different wallet.
forge script DeployMumbai --rpc-url $RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY --legacy
