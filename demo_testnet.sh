#!/usr/bin/env bash
#
# StreamPay - Monad testnet canlı demo (çok-aktörlü, gerçek işlemler).
#
# vm.warp/vm.prank cheatcode'ları gerçek ağda çalışmadığı için:
#  - 3 rol (employer/recipient/buyer) ayrı private key ile imzalar
#  - zaman gerçek beklemelerle (sleep) ilerler
#
# Çalıştırma:  bash demo_testnet.sh
#
set -euo pipefail

# --- Ortam ---
source .env
RPC="$MONAD_RPC_URL"
CONTRACT="$(node -e "console.log(require('./deployments.json').StreamPay)")"

EMP_PK="$PRIVATE_KEY"
EMP_ADDR="$(cast wallet address --private-key "$EMP_PK")"

# Oranlar (kontrat dakika bazlı): 1 MON/dk ve 2 MON/dk.
RATE1="1000000000000000000"   # 1 ether
RATE2="2000000000000000000"   # 2 ether
DEPOSIT="5ether"
WINDOW="30"                   # satış penceresi (saniye)

step() { echo ""; echo "=== $1 ==="; }
bal()  { cast balance "$1" --rpc-url "$RPC" --ether; }
send() { cast send "$@" --rpc-url "$RPC" --json | node -e "process.stdin.on('data',d=>{try{console.log('  tx:',JSON.parse(d).transactionHash)}catch(e){}})"; }

show_balances() {
  echo "  --- bakiyeler (MON) ---"
  echo "    employer  : $(bal "$EMP_ADDR")"
  echo "    recipient : $(bal "$RECIP_ADDR")"
  echo "    buyer     : $(bal "$BUYER_ADDR")"
  echo "    kontrat   : $(bal "$CONTRACT")"
}

# --- ADIM 1: cüzdanlar ---
step "ADIM 1: 2 yeni cuzdan uretiliyor ve fonlaniyor"
RECIP_JSON="$(cast wallet new --json)"
BUYER_JSON="$(cast wallet new --json)"
RECIP_ADDR="$(node -e "console.log(JSON.parse(process.argv[1])[0].address)" "$RECIP_JSON")"
RECIP_PK="$(node -e "console.log(JSON.parse(process.argv[1])[0].private_key)" "$RECIP_JSON")"
BUYER_ADDR="$(node -e "console.log(JSON.parse(process.argv[1])[0].address)" "$BUYER_JSON")"
BUYER_PK="$(node -e "console.log(JSON.parse(process.argv[1])[0].private_key)" "$BUYER_JSON")"
echo "  employer (mevcut): $EMP_ADDR"
echo "  recipient (yeni) : $RECIP_ADDR"
echo "  buyer (yeni)     : $BUYER_ADDR"
echo "  -> recipient'a 1 MON, buyer'a 2 MON gaz/fon gonderiliyor..."
send "$RECIP_ADDR" --value 1ether --private-key "$EMP_PK"
send "$BUYER_ADDR" --value 2ether --private-key "$EMP_PK"
show_balances

# --- ADIM 2: stream aç ---
step "ADIM 2: employer -> recipient stream aciyor (1 MON/dk, 5 MON depozit)"
SID="$(cast call "$CONTRACT" 'nextStreamId()(uint256)' --rpc-url "$RPC")"
echo "  streamId: $SID"
send "$CONTRACT" "createStream(address,uint256)" "$RECIP_ADDR" "$RATE1" --value "$DEPOSIT" --private-key "$EMP_PK"
show_balances

# --- ADIM 3: 1. claim ---
step "ADIM 3: ~20 sn bekle, recipient claim eder"
sleep 20
echo "  talep edilebilir (wei): $(cast call "$CONTRACT" 'claimableAmount(uint256)(uint256)' "$SID" --rpc-url "$RPC")"
send "$CONTRACT" "claim(uint256)" "$SID" --private-key "$RECIP_PK"
show_balances

# --- ADIM 4: adjustRate ---
step "ADIM 4: employer hizi 2 MON/dk'ya cikariyor"
send "$CONTRACT" "adjustRate(uint256,uint256)" "$SID" "$RATE2" --private-key "$EMP_PK"

# --- ADIM 5: 2. claim (yeni hız) ---
step "ADIM 5: ~20 sn bekle, recipient yeni hizla claim eder"
sleep 20
echo "  talep edilebilir (wei): $(cast call "$CONTRACT" 'claimableAmount(uint256)(uint256)' "$SID" --rpc-url "$RPC")"
send "$CONTRACT" "claim(uint256)" "$SID" --private-key "$RECIP_PK"
show_balances

# --- ADIM 6: gelecek talebi listele ---
step "ADIM 6: recipient gelecek ${WINDOW} sn'lik kazancini %5 indirimle satar"
SALE="$(cast call "$CONTRACT" 'nextSaleId()(uint256)' --rpc-url "$RPC")"
PRICE="$(node -e "console.log((${WINDOW}n*${RATE2}n/60n*95n/100n).toString())")"
echo "  saleId: $SALE | fiyat (wei): $PRICE"
send "$CONTRACT" "listFutureClaim(uint256,uint256,uint256)" "$SID" "$WINDOW" "$PRICE" --private-key "$RECIP_PK"

# --- ADIM 7: buyer satın alır ---
step "ADIM 7: buyer satisi aliyor (odeme aninda recipient'a gider)"
RECIP_BEFORE="$(bal "$RECIP_ADDR")"
send "$CONTRACT" "buyFutureClaim(uint256)" "$SALE" --value "$PRICE" --private-key "$BUYER_PK"
echo "  recipient bakiye once: $RECIP_BEFORE  sonra: $(bal "$RECIP_ADDR")"
show_balances

# --- ADIM 8: pencere içinde buyer claim, recipient EDEMEZ ---
step "ADIM 8: pencere icinde -> buyer claim eder, recipient REDDEDILIR"
sleep 12
echo "  -> recipient claim deneniyor (NOT_BUYER beklenir):"
if send "$CONTRACT" "claim(uint256)" "$SID" --private-key "$RECIP_PK" 2>/dev/null; then
  echo "  BEKLENMEDIK: recipient claim edebildi!"
else
  echo "  recipient claim REDDEDILDI (beklenen)"
fi
echo "  -> buyer claim ediyor:"
send "$CONTRACT" "claim(uint256)" "$SID" --private-key "$BUYER_PK"
show_balances

# --- ADIM 9: pencere bitti, hak recipient'a döner ---
step "ADIM 9: pencere bitince claim hakki recipient'a geri doner"
sleep 25
echo "  -> buyer claim deneniyor (NOT_RECIPIENT beklenir):"
if send "$CONTRACT" "claim(uint256)" "$SID" --private-key "$BUYER_PK" 2>/dev/null; then
  echo "  BEKLENMEDIK: buyer hala claim edebildi!"
else
  echo "  buyer claim REDDEDILDI (beklenen)"
fi
echo "  -> recipient claim ediyor:"
send "$CONTRACT" "claim(uint256)" "$SID" --private-key "$RECIP_PK"
show_balances

# --- ADIM 10: pauseStream ---
step "ADIM 10: employer pauseStream cagiriyor (son hak edis rezerve, kalan iade)"
send "$CONTRACT" "pauseStream(uint256)" "$SID" --private-key "$EMP_PK"
PENDING="$(cast call "$CONTRACT" 'pendingClaim(uint256)(uint256)' "$SID" --rpc-url "$RPC")"
echo "  recipient son hak edis (rezerve, wei): $PENDING"
if [ "$PENDING" != "0" ]; then
  echo "  -> recipient rezervi cekiyor:"
  send "$CONTRACT" "withdrawPending(uint256)" "$SID" --private-key "$RECIP_PK"
fi
ACTIVE="$(cast call "$CONTRACT" 'streams(uint256)(address,address,uint256,uint256,uint256,uint256,bool)' "$SID" --rpc-url "$RPC" | tail -n1)"
echo "  stream aktif mi: $ACTIVE"
show_balances

echo ""
echo "=== DEMO TAMAMLANDI ==="
