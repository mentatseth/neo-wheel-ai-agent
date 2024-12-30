## Usage

### Build

```shell
$ forge build
```

### Deployed Contract Info

- DamnsterFactory : [0x5279e8D74Cd2b789e33e6DDD0965e6d8072EC08B](https://xexplorer.neo.org/address/0x5279e8D74Cd2b789e33e6DDD0965e6d8072EC08B)

### Test Deploy Token in NEOX Mainnet

1. Copy .env.sample and fill in the following values
   ```
   NEO_MAIN_DEPLOYER=
   NEO_MAIN_PLAYER=
   NEO_RPC_URL=https://mainnet-1.rpc.banelabs.org
   ```
   - NEO_MAIN_PLAYER is used in `Damnster.Deploytoken.s.sol`
   - NEO_MAIN_DEPLOYER is used in `Damnster.neo.mainnet.s.sol`
2. Load the env variables
   ```
   source .env
   ```
3. Update custom token info in `./script/neo/Damnster.Deploytoken.s.sol`

   ```solidity
   /////////////////////////////
   // SETTING TOKEN : FIX HERE//
   /////////////////////////////

   string memory name = "DEMO";
   string memory symbol = "DEMO";
   address deployer = vm.addr(playerPrivateKey);
   bytes32 salt = "0x";
   uint256 fid = 0;
   string memory image = "";
   string memory castHash = "";
   ```

4. deploy token with NEO_MAIN_PLAYER address
   ```
   forge script script/neo/Damnster.Deploytoken.s.sol:DamnsterDeployTokenScript --rpc-url $NEO_RPC_URL --broadcast -vvvv --legacy
   ```
