-include .env

.PHONY: deploy 

NETWORK_ARGS := --rpc-url $(GANACHE_RPC_URL) --private-key $(GANACHE_PRIVATE_KEY) --broadcast  
ifeq ($(findstring --network sepolia,$(ARGS)), --network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployCrowdFunding.s.sol:DeployCrowdFunding $(NETWORK_ARGS)