FROM node:latest

# Set the SHELL to bash with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
### Installation
# updating system
RUN apt update
# insatlling sudo git, curl, jq, make
RUN apt install sudo
RUN apt install -y git curl make jq wget bash direnv
# installing Go
RUN wget https://go.dev/dl/go1.20.linux-amd64.tar.gz
RUN rm -rf go1.21.3.src.tar.gz
RUN tar xvzf go1.20.linux-amd64.tar.gz
RUN cp go/bin/go /usr/bin/go
RUN mv go /usr/local/
RUN echo export GOROOT=/usr/local/go >> ~/.bashrc
RUN echo 'node ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER node
WORKDIR /home/node
# # insatlling Node lts via NVM
# RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
# #RUN useradd -ms /bin/bash ubuntu
# # nvm
# RUN echo 'export NVM_DIR="$HOME/.nvm"'                                       >> "$HOME/.bashrc"
# RUN echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> "$HOME/.bashrc"
# RUN echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" # This loads nvm bash_completion' >> "$HOME/.bashrc"
# # nodejs and tools
# RUN bash -c 'source $HOME/.nvm/nvm.sh   && \
#     nvm install node                    && \
#     npm install -g doctoc urchin eclint dockerfile_lint && \
#     npm install --prefix "$HOME/.nvm/"'

# RUN source  ~/.bashrc
# installing foundry
RUN echo export PATH=$PATH:/home/node/.foundry/bin >> ~/.bashrc
ENV PATH="$PATH:/home/node/.foundry/bin"
RUN cd &&  bash -c "curl -L https://foundry.paradigm.xyz | bash"
RUN foundryup
# installing yarn and pnpm
# ### Build the Optimism Monorepo
RUN echo $PATH && echo $(pwd) && sleep 2
RUN cd && git clone --recurse-submodules https://github.com/ethereum-optimism/optimism.git
WORKDIR /home/node/optimism
RUN sudo npm i -g npm@10.2.1
RUN sudo npm i -g pnpm
RUN npx pnpm install && npx pnpm build
RUN make op-node op-batcher op-proposer
RUN make build

WORKDIR /home/node
# ### Build op-geth
RUN git clone https://github.com/ethereum-optimism/op-geth.git
WORKDIR /home/node/op-geth
RUN pnpm install geth
RUN make geth

# ###    Generate some keys
# #    You’ll need four accounts and their private keys when setting up the chain:

# ############################################################################################
# # The Admin account which has the ability to upgrade contracts.                            #
# # The Batcher account which publishes Sequencer transaction data to L1.                    #
# # The Proposer account which publishes L2 transaction results to L1.                       #
# # The Sequencer account which signs blocks on the p2p network.                             #
# # You can generate all of these keys with the rekey tool in the contracts-bedrock package. #
# ############################################################################################
RUN cd && cd optimism/packages/contracts-bedrock && echo "Admin:" \
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


RUN cd $HOME/optimism/packages/contracts-bedrock && cp .envrc.example .envrc && direnv allow .
# Fill out the environment variables inside of that file:

# ETH_RPC_URL — URL for your L1 node.
# PRIVATE_KEY — Private key of the Admin account.
# DEPLOYMENT_CONTEXT - Name of the network, should be "getting-started"
# Pull the environment variables into context using direnv

# If you need to install direnv, make sure you also modify the shell configuration (opens new window).

# Before we can create our configuration file, we’ll need to pick an L1 block to serve as the starting point for our Rollup. It’s best to use a finalized L1 block as our starting block. You can use the cast command provided by Foundry to grab all of the necessary information:

ARG ETH_RPC_URL="${ETH_RPC_URL}"
RUN cast block finalized --rpc-url $ETH_RPC_URL | grep -E "(timestamp|hash|number)"
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

ENTRYPOINT /bin/bash
