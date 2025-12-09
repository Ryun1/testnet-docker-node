#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/simple"
tx_path_stub="$txs_dir/send-to-many"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT=1000000

CSV_FILE=$project_root/utilities/committee-rewards-addresses.csv
METADATA_FILE=$project_root/utilities/committee-rewards-metadata.json

PAYMENT_ADDR="addr1qx93k28kzzu4fng49cfcj8w7m8px36wf9z8j94638lu8cw574gazl7xgwlxg4uxe4ytwnttj8qw489waumt82gx5jdtqwh8hn0"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# Check required files exist
if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Error: Payment address file not found: $keys_dir/payment.addr"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

if [ ! -f "$keys_dir/payment.skey" ]; then
  echo "Error: Payment signing key not found: $keys_dir/payment.skey"
  exit 1
fi


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
  echo "Error: CSV file not found: $CSV_FILE"
  exit 1
fi

# Verify header contains "address"
if ! head -1 "$CSV_FILE" | grep -q "address"; then
  echo "Error: CSV file must have 'address' column header"
  exit 1
fi

# Read addresses from CSV file (skip header, extract first column)
addresses=()
first_line=true
while IFS=',' read -r addr rest; do
  # Skip header line
  if [ "$first_line" = true ]; then
    first_line=false
    continue
  fi
  # Remove quotes and whitespace
  addr=$(echo "$addr" | xargs)
  if [ -n "$addr" ]; then
    addresses+=("$addr")
  fi
done < "$CSV_FILE"

# Check if we found any addresses
if [ ${#addresses[@]} -eq 0 ]; then
  echo "Error: No addresses found in CSV file"
  exit 1
fi

echo "Found ${#addresses[@]} addresses in CSV file"
echo "Sending $LOVELACE_AMOUNT lovelace to each address"

# Get UTXO from payment address

# payment_addr=$(cat $keys_dir/payment.addr)
payment_addr=$PAYMENT_ADDR
echo "Using payment address: $payment_addr"
# utxo_output=$(cardano_cli conway query utxo --address "$payment_addr" --out-file /dev/stdout)
# utxo=$(echo "$utxo_output" | jq -r 'keys[0]')

utxo="b35fdadd3c496fcc86f78f235de3aa2c091f88de5534e999f005ac4ad29aff8e#0"

if [ -z "$utxo" ] || [ "$utxo" = "null" ]; then
  echo "Error: No UTXO found at payment address"
  exit 1
fi

echo "Using UTXO: $utxo"

# Build transaction with multiple tx-out entries
echo "Building transaction"

build_args=(
  "conway" "transaction" "build"
  "--tx-in" "$utxo"
)

# Add tx-out for each address
for addr in "${addresses[@]}"; do
  build_args+=("--tx-out" "$addr+$LOVELACE_AMOUNT")
  echo ""--tx-out" "$addr+$LOVELACE_AMOUNT""
done

# cardano-cli conway transaction build \
#   --mainnet \
#   --tx-in "b35fdadd3c496fcc86f78f235de3aa2c091f88de5534e999f005ac4ad29aff8e#0" \
#   --tx-out addr1q8wlrs4ntlxpsf6k5c69f86e964pksty5mvsttkauk4yqfswx2v2y8xu6mgdulhcqszuuqkcxntj0899cxuyral4vrjsvc+$LOVELACE_AMOUNT \
#   --tx-out addr1q8r4hru8ncsr74faz8aj3hu2t4jujckfyv0a34x39344wpkppndn3ly7hepmyavkazs2tje3ketp0pn0pymcs0tm07jqv9+$LOVELACE_AMOUNT \
#   --tx-out addr1q9jzmf9326dn5eehsw68ctvkktq9um2x092d9kdesmcuucs220kw2x0lk964luk46gtlmkyamdzsnqscemshp9jr3j3s92+$LOVELACE_AMOUNT \
#   --tx-out addr1qxsxg746tsgfxw98gmcxsev37jfytxr809seeq6t87wdw7md78v5yq4uafh4lcx94pz45p47quhdttl93jtxa4n33sts57+$LOVELACE_AMOUNT \
#   --tx-out addr1qyyuf3ua0e2sjas9egqjqvza6ut3jyn0kxr3e5l2upeuasgsfm9826q0pkhau2kf6nuj0065dgejfen0kk6t7cg0d9yqed+$LOVELACE_AMOUNT \
#   --tx-out addr1q8vd7lvhd2sf9pys7p3wdcpdtqnpyrs0nz7lc2t6lny7ptsn3dddzfmkf7zn5kgelsgrg8xp3atxvagy2sprhdtv98uqzr+$LOVELACE_AMOUNT \
#   --tx-out addr1qx3nmmfgs3n2gj408vnh2frjpnj02me7q32ljrfln4cjrs0uc4cfa0u0qtc9trlafnzgzfz04rp9w27n87sy5zkj298s3k+$LOVELACE_AMOUNT \
#   --tx-out addr1q84zyxga7lru033v2ryuced3kxq0ca00mrjvegjamu6e33600un3vmjpt4nskfeg3nqwew6un5z4evducx0aprs7ka5s64+$LOVELACE_AMOUNT \
#   --tx-out addr1q85wy2qhmqnvl2xdsvqpv4f2q2x8lt3n623z0gvw0p6lx7rl9fzsf5c7jd47qey9necq5nva78tqh8q63vnf5eh4sagq2s+$LOVELACE_AMOUNT \
#   --tx-out addr1q9zaake0nwcxe09m7rg35xukhdw6v3qu0wzq7gguwf38kdyrf7u2rmeeq9ary0ds2ves9rt5luhpcg205zn77s2rzy3s9r+$LOVELACE_AMOUNT \
#   --tx-out addr1q8q25anxdp5hsmukxm99h7fh95rcuxed4ryk4jwzwhj7rpl8y7qqf0xuarfnjyljdqa2szayfdev9ytselvy47jh8aaq06+$LOVELACE_AMOUNT \
#   --tx-out addr1qylctn9a4h46ww7jsqah533s7ldrlrzn7mrhl5rdptrumn6ke58azzzukvzyymfk9ank0hx59vmg3e6htuuaqalar9qqyj+$LOVELACE_AMOUNT \
#   --tx-out addr1qyy8v6ryzthd3cf6z46ewkxedw40t82ne7krr0epq0hcuhcqqdgc7n2tswxsfhqyu2s6s8n62fm8w8dgnss2fk3q498spw+$LOVELACE_AMOUNT \
#   --tx-out addr1q9mcsgapzarg96n7cdt0m0l04jcr8lsypdh4jupcfg7u0tsuczyl9mps9cj5afffaudy6qk9hr7lts46xtqyrf77napspt+$LOVELACE_AMOUNT \
#   --tx-out addr1qxn6q4pj34utsalhs6ppjfl9fcp5h4rmvw6z594nuf6c8leymj34m5yg4hfcqcdqz9emf2avarj09h2atx0an6vvjjasw0+$LOVELACE_AMOUNT \
#   --tx-out addr1q9mm86mtnm4zuumnakzrzucfy72fqc2cecar0lagg58wdkkmrju2vl5ql0adr6nyvwa5qekr042gektv7ewzussye8qskk+$LOVELACE_AMOUNT \
#   --tx-out addr1q8zvq7dnczsfaf3s7uhpqdtk7rufru0qey3vmwge2tur6zuat40gj8ydxp0xuy6qwfe9y5hxh5amwsmfa8h7hwkz8yksrf+$LOVELACE_AMOUNT \
#   --tx-out addr1q99uk27c5wrj5qlumngpw6wcx2vgc6ew4e8rnh09mjsk6v0l3x8f7ny6el5zdpw9as2fctc6fxqqkmrzaelxdkudydaq4w+$LOVELACE_AMOUNT \
#   --tx-out addr1qxzcr6xfgu4u5dwhruqml9yj0v9j8l2vl3qcwdla4famv3vlex2jvsm78g26gu6sjg7t95a2y5s6whydc2vh73k7arws7s+$LOVELACE_AMOUNT \
#   --tx-out addr1qyr25mj9lcvkmfgg79ng35xdgqjk23rvypgtnjd9786xxm8pa7ucanumazwle37f3austjcyguxf4rl2p7ue4n4qnkjqk4+$LOVELACE_AMOUNT \
#   --tx-out addr1q82vx5jca42vx5n7qpu05vu8r6vxmvgc2nvuknmhnky7vpx0n6h44fq8ujuyu807vll9atjpc8z6zl0pyv6n2neezysq04+$LOVELACE_AMOUNT \
#   --tx-out addr1qy4daca3jj3jfj88n68r6nq0xktd0pg8qg8u846wks6kj3gfts83rwdnzxtqv7k2dalz2f98nx3pyz8d6k8djkxyxvfsp0+$LOVELACE_AMOUNT \
#   --tx-out addr1qygf8g0sd8v8tqha03nemmagj2s78sys4zdhun38c9a2p8mq7zcmh7er8kcgw6xfhdawk04hrtkt4x894dd3947x3xtqd9+$LOVELACE_AMOUNT \
#   --tx-out addr1q8g9grgfvupmww57krrqzjun8tsq8de5h67k66grtctwy4yz7kjjfjakkevmpsk4dk9scqtx9kr4u9s8av9nakrkh04s53+$LOVELACE_AMOUNT \
#   --tx-out addr1qyazppj7y0d8v8sp7ne4ngu8axkd8fq88zwaujn24fq85mnv52vtzx8s3g663v8qtt8g0ru27j7j6udsfkm7jzf5ypjs5t+$LOVELACE_AMOUNT \
#   --tx-out addr1qyav65zpcz56ulyzgjc76s9cgfjnxjrwdlpwsathdwf2l5lhj42k4j2wwqe5zytcpc0pvcpncwhp4jc40qvd3fjpg7ts4g+$LOVELACE_AMOUNT \
#   --tx-out addr1q8f5a2lr2xzt9989nkr2nv4zld2hj05v3tsdkvtc34dnlv8y0cwmpc3zw79z2z8sqma9cf75xz3kyglum84xsj3kzc4qh9+$LOVELACE_AMOUNT \
#   --tx-out addr1qy4xmqqvsx823906led0m9gerpfkyhgctsj8nysm3lhwx55s87338qzeuap40ddjfglelmsp8hymdwt0ly5eq4fqu5uqrd+$LOVELACE_AMOUNT \
#   --tx-out addr1q96smdr4zclu747uf26f2nqynulqmhze4ake4ua5mktharpzlj7prvw5z3p209ye0c4a34qqywsfp7chw5hul4rx4j8qrw+$LOVELACE_AMOUNT \
#   --tx-out addr1qxrdq3xk2wr6qqe2kjkdmtmpf2untcauwncl7vp4qqgseuc62a5358dy04zt0ek3a5m3u69dhp7ya4jzeyvvtnmf93rqdm+$LOVELACE_AMOUNT \
#   --tx-out addr1q9csfkv940e0juf3m8lftjr6s4eapx5vlkf05mrfag0y0csvlktu7n06027e588vf2mxt3uajup7r6kwvc45k3wgayqqvg+$LOVELACE_AMOUNT \
#   --tx-out addr1q9malun7ytnqh6z2zrajkhavx624577phc7xzxnwgkq726vj9sdxyx5ycvuczmr5yrqvvyet97xwvuepn9p4848wpraqp9+$LOVELACE_AMOUNT \
#   --tx-out addr1qysenuaxd49u74l8trz59mff7yxxlgwhpu8gj76w9pcpp038adkn5awy42fe9aq9yu2kjvuxqggxu220x7ktnscqyv0sea+$LOVELACE_AMOUNT \
#   --tx-out addr1qyyj2wuemm4sgx9fppezkark0mr97lhlk66j25ujnw2zs5x4p39tuzawxuf8afnlcp3mhl2ay0uyggeujrm5kct237rsa8+$LOVELACE_AMOUNT \
#   --tx-out addr1v83asw72qe5epvvwj8gg22cc5en4568gk2vephh8vxf22zsmv5kc2+$LOVELACE_AMOUNT \
#   --tx-out addr1qxsc5gppzecxezl82vkpp6j4g6tve62yg37kmltxtm7njwxe8v6sh93ufj38648njrmmcwpqhlf94mhd9p9r583sp0vsq6+$LOVELACE_AMOUNT \
#   --tx-out addr1q969pqdex204usts3dypdq592whk46hfe44s9k3n04h2hxe0tmwel0mj55vcggeqymqzz0h6fgvp0rdakhctl0s0nz7q7z+$LOVELACE_AMOUNT \
#   --tx-out addr1qx4t8uw8xne0f545cjdu9c2uhtezchw5h8hhnzfvwky4s8retdxxx9z84wts7ywszpfyzzu2m0xsttgffytp0t45pjvsdy+$LOVELACE_AMOUNT \
#   --tx-out addr1q95gj4xg4kwc6qp6m4cr5qfpxe5k9fyqlntx8cglssx7ty4nx4wa20lvsyj8lgvxrw6uw7fclma0p76us5fff6qxgvlqc9+$LOVELACE_AMOUNT \
#   --tx-out addr1q8ctar2qsmx8ffwz7ju868a459720m57jakj398s0hlqkrrlchtgtyzca7pxm2e3cdud8p7358ggxgv2xsm90e3l2r9qxu+$LOVELACE_AMOUNT \
#   --tx-out addr1qyevgjyszgryta92tj5phnvhnkc45t3dd08r2en6tdjrcnte69ykzwnem33zdglnk3rm6n2pl4xw6y0ackyke0vx0n7qkq+$LOVELACE_AMOUNT \
#   --tx-out addr1qxvqnvlnscsznw8p6369824hs8pra9vmwf6pw2y932736zhgqvcsrcpe0a74xm4mf8ymnzsza34q2e96jp9jxfnfwnhq9s+$LOVELACE_AMOUNT \
#   --tx-out addr1q9ynxme7c0tcmmvgk2tjuv63aw7zk9tk6yqkaqd48ulhkyl5f6v47dp5rc7286z5f57339d0c79khw4y3lwxzm8ywkzs02+$LOVELACE_AMOUNT \
#   --tx-out addr1q87qazerlfzc25p8wj4ecn9n6zmmdt62knsdjvs67hpwlsxylp3t9qnzvjnxatn7q04n03029k3nxssd3f66vv554rmsle+$LOVELACE_AMOUNT \
#   --tx-out addr1qy236l8zxnyvvm7uaxtvp87k36a045h8em0y82clams4wfuwpj9clsvsf85cd4xc59zjztr5zwpummwckmzr2myjwjnsrv+$LOVELACE_AMOUNT \
#   --tx-out addr1qxrqkurzqk2czm4zgmwsang735r3adhwmeadwen55hyrk5nu926a5u550v8yc52vmuyeyqs2rt7de9up65zxvynf5w8sum+$LOVELACE_AMOUNT \
#   --tx-out addr1qxyzre7hzxnm33xc0nk0hx3tz6g2yyz4524adfev0dz5ukd94zvpc45v3wht4rzg03qfkujcg4cpauscgj7s0n2dj6wspd+$LOVELACE_AMOUNT \
#   --tx-out addr1qyd0ffyzhwn4pqazdp8cs2j0l3taevqvgmrxrkw5f6ncck52ztpy62vems8lrklc3pd6rpvr28qwcnj8p5gvlpad9hlsjq+$LOVELACE_AMOUNT \
#   --tx-out addr1qycvusgng68pgnyu3zr6jkg9yyx3hq96734fhdqktmnffwkw2fkwcpv4v0g3m6y5antuhlwjplrv99whkt02un2dtwas6z+$LOVELACE_AMOUNT \
#   --tx-out addr1qx8xn0zwc6vrqm0lw7daql5x7x8tlale6tz005g2hhfn85av635z0fphdhmxujen259r4tr6veseej3whlxmkz8xe97qjc+$LOVELACE_AMOUNT \
#   --change-address "addr1qx93k28kzzu4fng49cfcj8w7m8px36wf9z8j94638lu8cw574gazl7xgwlxg4uxe4ytwnttj8qw489waumt82gx5jdtqwh8hn0" \
#   --out-file "./committee-rewards.unsigned"

# # Add change address
# build_args+=(
#   "--change-address" "$payment_addr"
# )

# # Add metadata if specified
# if [ -n "$METADATA_FILE" ]; then
#   if [ -f "$METADATA_FILE" ]; then
#     echo "Including metadata from: $METADATA_FILE"
#     build_args+=("--metadata-json-file" "$METADATA_FILE")
#   else
#     echo "Warning: Metadata file not found: $METADATA_FILE"
#     echo "Continuing without metadata..."
#   fi
# fi

# build_args+=("--out-file" "$tx_unsigned_path")

# cardano_cli "${build_args[@]}"

# # Check transaction file was created
# if [ ! -f "$tx_unsigned_path" ]; then
#   echo "Error: Failed to create unsigned transaction file"
#   exit 1
# fi

# # # Sign the transaction
# # echo "Signing transaction"

# # cardano_cli conway transaction sign \
# #   --tx-body-file "$tx_unsigned_path" \
# #   --signing-key-file "$keys_dir/payment.skey" \
# #   --out-file "$tx_signed_path"

# # # Check signed transaction file was created
# # if [ ! -f "$tx_signed_path" ]; then
# #   echo "Error: Failed to create signed transaction file"
# #   exit 1
# # fi

# # # Submit the transaction
# # echo "Submitting transaction"


# # cardano_cli conway transaction submit --tx-file $tx_signed_path

# # echo "Transaction submitted successfully!"
# # echo "Sent $LOVELACE_AMOUNT lovelace to ${#addresses[@]} addresses"

