# Running a docker Leios node on leiosnet

A guide to starting and interacting with a **Leios** node on **leiosnet**.

> **Heads up:** leiosnet runs the **Dijkstra** ledger era and the node is built from a
> prebuilt **Leios** image. Most things work like any other Cardano testnet, but a number of
> `cardano-cli` queries are not yet supported against Dijkstra. See
> [Caveats & known limitations](#caveats--known-limitations).

## What is leiosnet?

**leiosnet** is a public Cardano testnet running the **Dijkstra** era — the ledger era
that ships the **Leios** protocol. Its key properties:

- **Network magic:** `164`
- **Config:** the standard set of Cardano config/genesis files, **plus** a
  `dijkstra-genesis.json`, published under the `cardano-playground` environments.
- **Node:** a prebuilt Cardano node compiled for Dijkstra/Leios, published from the
  [`ouroboros-leios`](https://github.com/input-output-hk/ouroboros-leios) repo
  (`ghcr.io/input-output-hk/ouroboros-leios/cardano-node-leios`), rather than a numbered
  release built from source.

## How a Leios node differs from a normal node

| | Standard node | Leios node |
|---|---|---|
| **Image** | Built/published as a numbered `cardano-node` release | Prebuilt Leios image from `ouroboros-leios` |
| **Config** | Standard genesis files | Standard genesis files **+ `dijkstra-genesis.json`** |
| **Database** | Standard ledger DB only | Standard DB **plus** a side-loaded SQLite `leios.db` snapshot |
| **Platform** | Host-native | Published for `linux/amd64` only — runs under emulation (e.g. Rosetta) on Apple Silicon |

The published Leios image is missing the `liburing2` system library the node binary links
against, so a thin layer (or an equivalent post-install step) is usually needed to add it,
along with a `cardano-cli` binary for interacting with the node.

## Running a Leios node

The general flow is the same as any Cardano node:

1. Obtain the leiosnet config files (including `dijkstra-genesis.json`).
2. Pull the prebuilt Leios node image and patch in `liburing2` + `cardano-cli`.
3. **Side-load the `leios.db` snapshot** — download the SQLite database (and its `-wal`
   write-ahead log) from a leiosnet relay into the node's working directory, mounted
   read-write. If no relay is reachable this is non-fatal: the node simply starts with an
   empty Leios database and builds it from the chain. In this repo's setup the container
   entrypoint re-runs this side-load on **every** start (throttled), so a crashed node
   self-heals — see [Recovering from the `LeiosCert` crash](#recovering-from-the-leioscert-crash)
   and its [trade-offs](#leiosdb-auto-refresh-trade-offs).
4. Run the node against the leiosnet config, e.g.:

```bash
cardano-node run \
  --topology      topology.json \
  --config        config.json \
  --database-path db \
  --socket-path   node.socket \
  --host-addr     0.0.0.0 \
  --port          3001
```

### Recovering from the `LeiosCert` crash

A current Leios node bug can hard-crash the node with:

```
cardano-node: ExceptionInLinkedThread ... Announced EB is being certified by the
current chain but it's not available?LeiosCert
```

This means the local `leios.db` is missing an endorsement block (EB) that the chain
references. The fix is to re-side-load `leios.db` from a relay that has the block.

**This now self-heals.** The container's entrypoint re-side-loads `leios.db` on *every*
start, so the `restart: always` policy turns a crash into an automatic recovery: crash →
Docker restarts the container → entrypoint downloads a fresh `leios.db` → node resumes.
Re-downloads are throttled (`LEIOS_DB_REFRESH_MIN_INTERVAL`, default `600` seconds) so a
rapid crash loop doesn't re-pull the ~190 MB snapshot on every restart.

To force a refresh manually (e.g. recover immediately without waiting for a restart), run:

```bash
./scripts/helper/refresh-leios-db.sh
```

It stops the leios container, re-downloads `leios.db` (+ `-wal`) using the same relay
list as the entrypoint and `start-node.sh`, and brings the node back up.

## Interacting with the node

`cardano-cli` connects to the node over the socket set in `CARDANO_NODE_SOCKET_PATH`, and
uses the network magic (`164`) — either via `--testnet-magic 164` or the
`CARDANO_NODE_NETWORK_ID=164` environment variable.

### Check the tip / sync progress

```bash
cardano-cli query tip --testnet-magic 164
```

You should see `"era": "Dijkstra"` and `"syncProgress"` climbing toward `100.00`.

### Queries that work today

These are era-agnostic and work against a Dijkstra node:

- `query tip`
- `query era-history`
- `query tx-mempool info`
- `query slot-number <timestamp>`

### Leios key tooling (offline)

The `dijkstra node` command group provides **offline** key operations (no node connection),
including the new BLS keys Leios needs:

```bash
cardano-cli dijkstra node key-gen-BLS   ...   # Leios BLS operational key pair
cardano-cli dijkstra node key-hash-BLS  ...   # hash of a BLS key
cardano-cli dijkstra node issue-pop-BLS ...   # BLS proof-of-possession
```

`issue-pop-BLS` (proof-of-possession) is required for a pool to act as a voting /
block-producing node under Leios. The usual `key-gen`, `key-gen-KES`, `key-gen-VRF`,
`issue-op-cert`, and `new-counter` operations are also available.

## Caveats & known limitations

### `cardano-cli` Dijkstra gaps

`cardano-cli` `11.0.0.0` ships an **incomplete Dijkstra implementation**. The node is
healthy, but any query that reads Shelley-based-era ledger state is **blocked CLI-side**,
including:

- `query protocol-parameters`, `query utxo`
- `query stake-pools`, `query stake-distribution`, `query stake-address-info`
- `query ledger-state`, `query protocol-state`, `query pool-state`, `query stake-snapshot`
- all Conway governance queries (`gov-state`, `committee-state`, `drep-state`, …)

As a result, transaction / stake / DRep / governance workflows that read ledger state **do
not work against leiosnet yet**. These gaps are expected to close in a later `cardano-cli`
release.

For the full command-by-command support matrix and root-cause details, see
[**cardano-cli ⇄ Dijkstra / Leios compatibility**](./dijkstra-cli-compatibility.md).

### `leios.db` auto-refresh trade-offs

The container entrypoint re-side-loads `leios.db` on every start (see
[Recovering from the `LeiosCert` crash](#recovering-from-the-leioscert-crash)). This is what
makes the crash self-heal, but it has consequences to be aware of:

- **Workaround, not a fix.** The underlying `LeiosCert` ("announced EB … not available")
  fault is an upstream Leios node bug. The auto-refresh masks it by swapping in a relay
  snapshot that contains the missing block; it does not fix the node itself.
- **Local Leios state is discarded on refresh.** Each refresh replaces the node's local
  `leios.db` with the relay's snapshot, so any Leios state the node built since the last
  side-load is thrown away and the node adopts the relay's view. Fine for a passive
  sync/relay node; **be cautious on a block-producing node** — wholesale replacement of
  `leios.db` is not something you want happening unexamined on a BP. Consider a large
  `LEIOS_DB_REFRESH_MIN_INTERVAL`, or removing the entrypoint refresh, for a producer.
- **Healthy restarts also re-download.** A daemon restart, host reboot, or manual
  `docker restart` more than `LEIOS_DB_REFRESH_MIN_INTERVAL` (default `600s`) after the last
  refresh re-pulls the full ~190 MB snapshot, even though nothing was wrong. Raise the
  interval if that bandwidth/latency matters.
- **Throttle is attempt-based, not success-based.** The `.leios-db-refreshed` marker (in the
  `leios/` dir, next to `leios.db`) is stamped on every attempt, including *failed* ones, so
  a crash loop with unreachable relays doesn't retry every restart. The flip side: after a
  failed refresh, a restart inside the interval **won't** retry — run
  `./scripts/helper/refresh-leios-db.sh` (or lower the interval) to retry sooner.
- **Relay dependency.** If no relay is reachable at start, the refresh is non-fatal but the
  node comes up with an *empty* `leios.db` and rebuilds from chain — slower, and it may hit
  the same `LeiosCert` crash again until it can obtain the missing EB.
- **Requires `curl` + `ca-certificates` in the image.** The entrypoint downloads over HTTPS,
  so the patched image installs these (see `Dockerfile.leios-image`). The base Leios image
  does not ship them.
