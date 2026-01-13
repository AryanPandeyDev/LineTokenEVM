-include .env

deploy:
	@forge script script/DeployLineToken.s.sol:DeployLineToken --rpc-url 127.0.0.1:8545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --legacy --broadcast


approve:
	@forge script script/Interactions.s.sol:ApproveLineToken --rpc-url 127.0.0.1:8545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --legacy --broadcast

test-transfer:
	forge test --mt testTransferMovesFundsBetweenWallets --rpc-url 127.0.0.1:8545 -vvv


test-transfer-from:
	forge test --mt testTransferFromDoesTransferFunds --rpc-url 127.0.0.1:8545 -vvv