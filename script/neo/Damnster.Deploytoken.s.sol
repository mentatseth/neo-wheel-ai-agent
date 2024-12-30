// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DamnsterFactory} from "../../src/DamnsterFactory.sol";
import {DamnsterToken} from "../../src/DamnsterToken.sol";


contract DamnsterDeployTokenScript is Script {
    DamnsterFactory public damnsterFactory;

    function setUp() public {
        damnsterFactory = DamnsterFactory(payable(0x5279e8D74Cd2b789e33e6DDD0965e6d8072EC08B));
    }

    function run() public {
        uint256 playerPrivateKey = vm.envUint("NEO_MAIN_PLAYER");
        vm.startBroadcast(playerPrivateKey);
        console.log("Player Address:", vm.addr(playerPrivateKey));

        /////////////////////////////
        // SETTING TOKEN : FIX HERE//
        ///////////////..........////
        string memory name = "DEMO";  
        string memory symbol = "DEMO";  
        address deployer = vm.addr(playerPrivateKey); 
        bytes32 salt = "0x";  
        uint256 fid = 0;  
        string memory image = "";  
        string memory castHash = "";  

        //////////////////
        // DEPLOY TOKEN //
        //////////////////
        (DamnsterToken token, address pool, uint256 tokenId) = damnsterFactory.deployToken(
            name,
            symbol,
            100000000000000000000000000000,
            -230400,
            10000,
            salt,
            deployer, 
            fid,
            image,
            castHash,
            DamnsterFactory.DevInputInfo(address(0), 0, 0, 0, 0, "", "")
        );

        console.log("New Token Address: ", address(token));

        vm.stopBroadcast();
    }
}

// main verify
// forge script script/neo/Damnster.Deploytoken.s.sol:DamnsterDeployTokenScript --rpc-url $NEO_RPC_URL --broadcast -vvvv --legacy