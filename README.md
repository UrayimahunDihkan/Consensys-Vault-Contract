forge script script/SmartWalletScript.s.sol --fork-url $SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY 
    --verify --etherscan-api-key $ETHERSCAN_KEY --chain-id 11155111

SmartWallet deployed at: 0xDE57aEDAC1B7425C1E5368E7E8A1FF1C891d9884

ABI:
jq '.abi' ./out/SmartWallet.sol/SmartWallet.json >  ./out/SmartWallet.sol/SmartWallet.abi.json# Consensys-Vault-Contract
