#!/bin/sh

# # Set the SHELL to bash with pipefail option
# SHELL ["/bin/bash", "-o", "pipefail", "-c"]
### Installation
# nodejs
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
# updating system
sudo apt-get update && sudo apt-get install nodejs -y
# insatlling sudo git, curl, jq, make
sudo apt install sudo
sudo apt install -y git curl make jq wget bash direnv docker.io
# installing Go
wget https://go.dev/dl/go1.20.linux-amd64.tar.gz
tar xvzf go1.20.linux-amd64.tar.gz
rm -rf go1.21.3.src.tar.gz
sudo cp go/bin/go /usr/bin/go
sudo mv go /usr/local/
echo export GOROOT=/usr/local/go >> ~/.bashrc
sudo su - -c "echo 'node ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"

# RUN source  ~/.bashrc
# installing foundry
echo export PATH=${PATH}:/home/node/.foundry/bin >> ~/.bashrc
export PATH="${PATH}:${HOME}/.foundry/bin"
cd &&  bash -c "curl -L https://foundry.paradigm.xyz | bash"
foundryup
# installing yarn and pnpm
# ### Build the Optimism Monorepo
cd && git clone --recurse-submodules https://github.com/ethereum-optimism/optimism.git
cd optimism
npx npm i -g npm@10.2.1
npx npm i -g pnpm
npx pnpm install && npx pnpm build
make op-node op-batcher op-proposer
make build

# Once finished, run `docker run -ti --rm softsky/op-l2:latest`, then from inside the container run `make devnet-up`

cd

# ### Build op-geth
git clone https://github.com/ethereum-optimism/op-geth.git
cd op-geth
npx pnpm install geth
make geth

# ###    Generate some keys
# #    You’ll need four accounts and their private keys when setting up the chain:

# ############################################################################################
# # The Admin account which has the ability to upgrade contracts.                            #
# # The Batcher account which publishes Sequencer transaction data to L1.                    #
# # The Proposer account which publishes L2 transaction results to L1.                       #
# # The Sequencer account which signs blocks on the p2p network.                             #
# # You can generate all of these keys with the rekey tool in the contracts-bedrock package. #
# ############################################################################################
cd && cd optimism/packages/contracts-bedrock && echo "Admin:" \
    cast wallet new \
    echo "Proposer:" \
    cast wallet new \
    echo "Batcher:" \
    cast wallet new \
    echo "Sequencer:" \
    cast wallet new

# ###################################################################################
# # Admin:                                                                          #
# # Successfully created new keypair.                                               #
# # Address:     0x9f92bdF0db69264462FC305913960Edfcc7a7c7F                         #
# # Private key: 0x30e66956e1a12b81f0f2cfb982286b2f566eb73649833831d9f80b12f8fa183c #
# # Proposer:                                                                       #
# # Successfully created new keypair.                                               #
# # Address:     0x31dE9B6473fc47af36ec23878bA34824B9F4AB30                         #
# # Private key: 0x8bd1c8dfffef880f8f9ab8162f97ccd119c1aac28fe00dacf919459f88e0f37d #
# # Batcher:                                                                        #
# # Successfully created new keypair.                                               #
# # Address:     0x6A3DC843843139f17Fcf04C057bb536A421DC9c6                         #
# # Private key: 0x3ce44144b7fde797a28f4e47b210a4d42c3a3b642e538b54458cba2740db5ac2 #
# # Sequencer:                                                                      #
# # Successfully created new keypair.                                               #
# # Address:     0x98C6cadB1fe77aBB7bD968fC3E9b206111e72848                         #
# # Private key: 0x3f4241229bb6f155140d98e0f5dd2aad7ae983f5af5d61555d05eb8e5d9514db #
# ###################################################################################


# ### Configure your network
# # Once you’ve built both repositories, you’ll need to head back to the Optimism Monorepo to set up the configuration for your chain. Currently, chain configuration lives inside of the contracts-bedrock (opens new window)package.

# # Enter the Optimism Monorepo:


cd $HOME/optimism/packages/contracts-bedrock && cp .envrc.example .envrc && direnv allow .
# Fill out the environment variables inside of that file:

# ETH_RPC_URL — URL for your L1 node.
# PRIVATE_KEY — Private key of the Admin account.
# DEPLOYMENT_CONTEXT - Name of the network, should be "getting-started"
# Pull the environment variables into context using direnv

# If you need to install direnv, make sure you also modify the shell configuration (opens new window).

# Before we can create our configuration file, we’ll need to pick an L1 block to serve as the starting point for our Rollup. It’s best to use a finalized L1 block as our starting block. You can use the cast command provided by Foundry to grab all of the necessary information:

export ETH_RPC_URL="${ETH_RPC_URL}"
export DEPLOYMENT_CONTEXT="${DEPLOYMENT_CONTEXT}"
export TENDERLY_PROJECT="${TENDERLY_PROJECT}"
export TENDERLY_USERNAME="${TENDERLY_USERNAME}"
export ETHERSCAN_API_KEY="${ETHERSCAN_API_KEY}"

export ETHERSCAN_API_KEY="${ETHERSCAN_API_KEY}"
cast block finalized --rpc-url $ETH_RPC_URL | grep -E "(timestamp|hash|number)"
# You’ll get back something that looks like the following:


# hash                 0x784d8e7f0e90969e375c7d12dac7a3df6879450d41b4cb04d4f8f209ff0c4cd9
# number               8482289
# timestamp            1676253324
# Fill out the remainder of the pre-populated config file found at deploy-config/getting-started.json (opens new window). Use the default values in the config file and make following modifications:

# Replace "ADMIN" with the address of the Admin account you generated earlier.
# Replace "PROPOSER" with the address of the Proposer account you generated earlier.
# Replace "BATCHER" with the address of the Batcher account you generated earlier.
# Replace "SEQUENCER" with the address of the Sequencer account you generated earlier.
# Replace "BLOCKHASH" with the blockhash you got from the cast command.
# Replace TIMESTAMP with the timestamp you got from the cast command. Note that although all the other fields are strings, this field is a number! Don’t include the quotation marks

cd ~/optimism
wget -c https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.13.4-3f907d6a.tar.gz -O - | tar xz
sudo mv geth-linux-amd64-1.13.4-3f907d6a/geth /usr/local/bin
rm -rf geth-linux-amd64-1.13.4-3f907d6a
npx nx reset
make build
