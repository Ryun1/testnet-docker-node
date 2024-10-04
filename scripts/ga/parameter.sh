#!/bin/sh

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
prev_ga_hash=""
prev_ga_index="0"

METADATA_URL="https://buy-ryan-an-island.com"
METADATA_HASH="0000000000000000000000000000000000000000000000000000000000000000"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Building, signing and submitting an parameter change governance action
echo "Creating and submitting parameter change governace action."

echo "\nPull the latest guardrails script."
curl --silent -J -L https://book.world.dev.cardano.org/environments/mainnet/guardrails-script.plutus -o ./txs/guardrails-script.plutus

echo "\nGet the guardrails script hash from the genesis file."
SCRIPT_HASH=$(jq -r ".constitution.script" "./node/config/conway-genesis.json")
echo "Script hash: $SCRIPT_HASH"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti sancho-node cardano-cli "$@"
}

container_cli conway governance action create-protocol-parameters-update \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state --testnet-magic 4 | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file ./keys/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --constitution-script-hash "$SCRIPT_HASH" \
  --key-reg-deposit-amt 3000000 \
  --out-file ./txs/parameter.action

  # --prev-governance-action-tx-id "$prev_ga_hash" \
  # --prev-governance-action-index "$prev_ga_index" \

container_cli conway transaction build \
 --testnet-magic 4 \
 --proposal-script-file ./txs/guardrails-script.plutus \
 --tx-in "$(container_cli query utxo --address "$(cat ./keys/payment.addr)" --testnet-magic 4 --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in "$(container_cli query utxo --address "$(cat ./keys/payment.addr)" --testnet-magic 4 --out-file /dev/stdout | jq -r 'keys[1]')" \
 --tx-in "$(container_cli query utxo --address "$(cat ./keys/payment.addr)" --testnet-magic 4 --out-file /dev/stdout | jq -r 'keys[2]')" \
 --tx-in-collateral "$(container_cli query utxo --address "$(cat ./keys/payment.addr)" --testnet-magic 4 --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-redeemer-value {} \
 --change-address "$(cat ./keys/payment.addr)" \
 --proposal-file ./txs/parameter.action \
 --out-file ./txs/parameter.action.raw

container_cli conway transaction sign \
 --tx-body-file ./txs/parameter.action.raw \
 --signing-key-file ./keys/payment.skey \
 --testnet-magic 4 \
 --out-file ./txs/parameter.action.signed

container_cli conway transaction submit \
 --testnet-magic 4 \
 --tx-file ./txs/parameter.action.signed

