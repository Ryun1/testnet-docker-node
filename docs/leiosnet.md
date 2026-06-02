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
   empty Leios database and builds it from the chain. In this repo's setup `start-node.sh`
   does this initial side-load, and a container supervisor re-side-loads **only when the
   node actually crashes** — see
   [Recovering from the `LeiosCert` crash](#recovering-from-the-leioscert-crash) and its
   [trade-offs](#leiosdb-recovery-trade-offs).
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
references. The fix is to obtain a `leios.db` that has the block (from a relay, or by
rebuilding from the chain).

**This self-heals.** The container's entrypoint (`scripts/helper/leios-entrypoint.sh`) is a
**supervisor**: it runs the node, watches its stderr, and when it sees the `LeiosCert`
crash it **escalates** recovery and re-runs the node — repeating until the node stays up:

1. refresh `leios.db` from relay 1, then
2. relay 2, then
3. relay 3, then
4. **wipe** `leios.db` and let the node rebuild Leios state from the chain it already trusts,

then it cycles back to relay 1 (which may have caught up), and so on. Recovery is tied to the
*actual* crash — a healthy node is never re-downloaded, and there is no throttle window to get
stuck in. `restart: always` remains only as an outer safety net for non-`LeiosCert` failures.
A `docker stop` is clean: the supervisor forwards `SIGTERM` to the node so SQLite closes
without corrupting `leios.db`.

You normally don't need to do anything. To force recovery by hand (e.g. immediately, or to
re-side-load before starting), run:

```bash
./scripts/helper/refresh-leios-db.sh
```

It stops the leios container, re-downloads `leios.db` (+ `-wal`) from the relays, and brings
the node back up.

> **The honest caveat:** escalation maximizes the chance of obtaining the missing EB and never
> gets permanently stuck, but it cannot conjure an EB that *no* relay and *no* peer has — that
> is the upstream bug. If every source is behind the block your chain references, the
> supervisor will keep cycling until one of them catches up.

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

### `leios.db` recovery trade-offs

The container supervisor recovers `leios.db` only when the node crashes, escalating relays →
wipe (see [Recovering from the `LeiosCert` crash](#recovering-from-the-leioscert-crash)).
Things to be aware of:

- **Workaround, not a fix.** The underlying `LeiosCert` ("announced EB … not available")
  fault is an upstream Leios node bug. Recovery masks it by obtaining a `leios.db` that has
  the missing block; it does not fix the node itself.
- **Recovery replaces local Leios state.** Each relay refresh swaps in the relay's snapshot,
  and the wipe step discards `leios.db` entirely — so any Leios state the node built is lost
  and rebuilt. This only happens on a crash, but **be cautious on a block-producing node**:
  wholesale replacement of `leios.db` is not something you want happening unexamined on a BP.
  Tune `LEIOS_RECOVERY_BACKOFF_SECONDS`, or run a producer without the supervisor's wipe step,
  if that matters.
- **Recovery is not instant.** Each attempt pulls a fresh snapshot (~190 MB) or triggers a
  chain rebuild, and on emulated `amd64` this is slow. The node is down for the duration of
  each attempt; the supervisor waits `LEIOS_RECOVERY_BACKOFF_SECONDS` (default `10`) between
  attempts to avoid hammering the relays.
- **It can keep cycling.** If no relay and no peer has the EB your chain references, escalation
  rotates relay → relay → relay → wipe → relay … indefinitely rather than fixing it — it
  never gets *stuck*, but it can't recover until some source has the block. Watch
  `docker logs` to see the attempt counter climbing.
- **Non-`LeiosCert` crashes are not auto-recovered.** Any other non-zero exit is left to the
  compose `restart: always` policy (the supervisor does not loop on it), so unrelated failures
  aren't masked behind a tight retry loop.
- **Requires `curl` + `ca-certificates` in the image.** Relay refreshes download over HTTPS,
  so the patched image installs these (see `Dockerfile.leios-image`). The base Leios image
  does not ship them.
