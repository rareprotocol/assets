
help: ## Ask for help!
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

clean: ## clean.
	@bash -l -c 'forge clean'

build: ## Build the smart contracts with foundry.
	@bash -l -c 'forge build'
	scripts/copy_abis.sh

test: ## Run foundry unit tests.
	@bash -l -c 'forge test'
