
# Cardano Testnet Node Toolkit 🤠

A simple Cardano node toolkit,
interact with Cardano nodes running in docker or connect via socket file.

Allowing the user to run multiple dockerised nodes,
with different versions and across networks.

**Docker node version choices:** `10.5.3`, `10.5.1`

## Prerequisites

### `Docker`

Install docker desktop for your operating system.

- <https://docs.docker.com/engine/install>

If you are using Apple silicon (M1, M2, M3 processor) make sure you have Rosetta
enabled via Docker desktop settings.

### Visual Studio Code

Install VSCode so we can more easily navigate directories, and inspect files.

- <https://code.visualstudio.com/>

### Mac Specific Prerequisites

1. xcode tools.

```zsh
xcode-select --install
```

2. Rosetta.

```zsh
softwareupdate --install-rosetta
```

### Windows Specific Prerequisites

Windows Subsystem for Linux.

[How to Install WSL on Windows](https://learn.microsoft.com/en-us/windows/wsl/install)

## Setup Guide

### 1. Clone this repository

You may want to make a nice folder/directory for this first.

Clone into current directory.

```bash
git clone https://github.com/Ryun1/testnet-docker-node.git
```

### 2. Open `testnet-docker-node` from within Visual Studio Code

Open Visual Studio Code and then go `File > Open Folder` selecting `testnet-docker-node` folder.

![Open Folder VS Code](./docs/images/setup-2.png)

### 3. Open a terminal in Visual Studio Code

Open a terminal inside of VSCode.

![Open Terminal Console](./docs/images/setup-3.png)

### 4. Update script permissions

Inside the terminal console, give scripts execute file permissions.

Windows users will have to run this first, to access the wsl environment.

```bash
wsl
```

Run the following command.

```zsh
chmod +x ./start-node.sh ./stop-nodes.sh ./scripts/*
```

![Fix permissions](./docs/images/setup-4.png)

**Note:** Make sure your terminal shows the correct directory `testnet-docker-node`.

## Basic Usage

**Note:** Before any usage ensure you have docker desktop open and running.

### Start node

We have a script that:

- pulls the latest testnet node configs
- pulls the Cardano node docker image
- builds and runs the Cardano node image
- pushes the node logs to the terminal

In your terminal execute:

```bash
./start-node.sh
```

Then choose which network to work on.

If you want to stop the logs (but the node is still running) you can press `control + c`.

This should look something like:

![Starting node](./docs/images/usage-start.png)

**Note:** The first time you do this the node will take a long time to synchronize to the network.

### Check node is running

#### 1. Open a new terminal

Press the plus at the top right of your terminal window.

![Open new terminal](./docs/images/usage-check-1.png)

And then click on the new terminal.

![Navigate to new terminal](./docs/images/usage-check-1-b.png)

#### 2. Query tip of node

Run the node query tip script.

Windows users will have to run this first, to access the wsl environment.

```bash
wsl
```

In your second terminal execute:

```bash
./scripts/node-query-tip.sh
```

For a fully synced node the terminal should return, with `syncProgress` of `100.00`.

```json
{
    "block": 1185368,
    "epoch": 277,
    "era": "Conway",
    "hash": "13d654899faabb50522f7f608e8d627acaaa8206347c913b0e74754538754eb5",
    "slot": 24011698,
    "slotInEpoch": 78898,
    "slotsToEpochEnd": 7502,
    "syncProgress": "100.00"
}
```

For a un-fully synced node the terminal should return, with `syncProgress` of less than `100.00`.
You will have to wait till fully synced node before being able to interact with the network.

```json
{
    "block": 14646,
    "epoch": 3,
    "era": "Babbage",
    "hash": "d72cb1cfb7f7eb9d457d48c0d3e165170565eb371f8f5c7cb3d6d212be97c797",
    "slot": 292713,
    "slotInEpoch": 33513,
    "slotsToEpochEnd": 52887,
    "syncProgress": "1.22"
}
```

### Stop node

This script will stop your Cardano node, remember to run this when you are done using your node.

In your second terminal execute:

```bash
./stop-docker.sh
```

## Doing Stuff

Now you have a node you can actually ✨*do fun stuff*✨

### Setup keys and get tAda

#### 1. Generate keys, addresses and a DRep ID

We have a script that:

- randomly generates a set of payment, stake and DRep keys
- from keys, creates addresses and a DRep ID

In a terminal execute:

```bash
./scripts/generate-keys.sh
```

This will create you a keys directory with some fun things inside, looks like this:

![New keys and addresses](./docs/images/doing-1.png)

#### 2. Get some tAda

Get yourself some test ada, so you can pay for transaction fees.

Open your new address from [./keys/payment.addr](./keys/payment.addr).

Go to the [Testnet faucet](https://docs.cardano.org/cardano-testnets/tools/faucet) and request some tAda sent to your new address.

### Run Scripts

Check out the [scripts folder](./scripts/) and see what you'd like to do.

I will give an example of what you could do.

Make sure you have a node running for these.

#### Become a DRep, delegate to self and vote

##### 1. Register as a DRep

```bash
./scripts/drep/register.sh
```

##### 2. Register your stake key (needed before delegating)

```bash
./scripts/stake/key-register.sh
```

##### 3. Delegate your tAda's voting rights to yourself

```bash
./scripts/drep/delegate-to-self.sh
```

## Using Multiple Nodes and External Nodes

This toolkit supports connecting to multiple Cardano nodes simultaneously - both Docker containers and external nodes running outside of Docker. You can run scripts against different networks and nodes at the same time.

### External Node Configuration

External nodes use environment variables `CARDANO_NODE_SOCKET_PATH` and `CARDANO_NODE_NETWORK_ID`. You can configure these through the `start-node.sh` script, which will prompt you for the values and confirm them before use.

**Important:** Only one external node connection is supported at a time. For multiple external nodes, switch environment variables between script executions.

#### Setting Up External Node

Use the `start-node.sh` script to configure:

```bash
./start-node.sh
# Select: "Configure connection to an external node via socket file"
# Enter socket path and network ID
# Confirm the values
```

Or set environment variables directly:

```bash
export CARDANO_NODE_SOCKET_PATH="/path/to/node.socket"
export CARDANO_NODE_NETWORK_ID=1  # 1=preprod, 2=preview, 4=sanchonet

# Run scripts
./scripts/query/tip.sh
```

#### Network Magic Numbers

- **preprod**: Network ID `1`
- **preview**: Network ID `2`
- **sanchonet**: Network ID `4`

### Multiple Docker Containers

When multiple Docker containers are running, the toolkit will:
- **Automatically select** the only container if only one is running
- **Prompt you to choose** if multiple containers are running (interactive mode)
- **Use the first container** if running non-interactively (no TTY)

To avoid prompts, specify the container name:

```bash
CARDANO_CONTAINER_NAME="node-preprod-10.5.3-container" ./scripts/query/tip.sh
```

### Single Node Configuration (Backward Compatible)

For backward compatibility, you can still use the old single-node format:

```json
{
  "socket_path": "/path/to/your/node.socket",
  "network": "preprod",
  "network_id": 1,
  "mode": "external"
}
```

### Requirements

- **Local cardano-cli**: When using external node mode, you must have `cardano-cli` installed locally and available in your PATH
- **Network restriction**: Mainnet connections via external sockets are **not allowed** for security reasons. Only testnet networks (preprod, preview, sanchonet) are supported
- **Socket file**: The socket file must be accessible and the node must be running

### Network Magic Numbers

- **preprod**: Network ID `1`
- **preview**: Network ID `2`
- **sanchonet**: Network ID `4`
- **mainnet**: Network ID `764824073` (blocked for external nodes, allowed in Docker mode)

### Example: Running Scripts Against Multiple Networks

```bash
# Terminal 1: Query preprod via external node
CARDANO_NODE_SOCKET_PATH="/path/to/preprod.socket" CARDANO_NODE_NETWORK_ID=1 ./scripts/query/tip.sh

# Terminal 2: Query preview via external node (switch env vars)
CARDANO_NODE_SOCKET_PATH="/path/to/preview.socket" CARDANO_NODE_NETWORK_ID=2 ./scripts/query/tip.sh

# Terminal 3: Use Docker container for mainnet
CARDANO_CONTAINER_NAME="node-mainnet-10.5.3-container" ./scripts/query/tip.sh
```

### Node Selection Priority

The toolkit uses the following priority order:

1. `CARDANO_NODE_SOCKET_PATH` + `CARDANO_NODE_NETWORK_ID` - External node (environment variables)
2. `CARDANO_CONTAINER_NAME` - Direct container name specification (for Docker mode)
3. Docker mode with container selection - Default fallback

**Note:** External nodes require both `CARDANO_NODE_SOCKET_PATH` and `CARDANO_NODE_NETWORK_ID` to be set. Use the `start-node.sh` script to configure and confirm these values.

### Version Check

When using external node mode, the toolkit will automatically check and display your local `cardano-cli` version and which node is being used. If `cardano-cli` is not found in PATH, you'll receive a warning.

## Common Error Messages

### Docker desktop application not open

```bash
Cannot connect to the Docker daemon at unix:///Users/XXXX/.docker/run/docker.sock. Is the docker daemon running?
```

**Fix:** Open docker desktop

### Mainnet connection blocked

```bash
Error: Mainnet connections are not allowed. Please use testnet networks (preprod, preview, sanchonet) only.
```

**Fix:** This error appears when attempting to connect to mainnet via external socket. Use Docker mode for mainnet, or switch to a testnet network.

### cardano-cli not found

```bash
Warning: cardano-cli not found in PATH. External node mode requires cardano-cli to be installed locally.
```

**Fix:** Install `cardano-cli` locally and ensure it's in your PATH when using external node mode.
