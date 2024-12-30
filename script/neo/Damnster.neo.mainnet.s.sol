// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {UnsafeUpgrades} from "lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {DamnsterFactory} from "../../src/DamnsterFactory.sol";
import {DamnsterLens} from "../../src/DamnsterLens.sol";
import {LockerFactory} from "../../src/LockerFactory.sol";

contract DamnsterScript is Script {
    DamnsterFactory public damnsterFactory;
    LockerFactory public lockerFactory;
    DamnsterLens public damnsterLens;

    address degen = address(0);
    address dpad = address(0);

    // wallet
    address damnsterFactoryOwner = 0x99c368122eFcA256541F1ea807eb17e3E529D813; // TODO 0x99c368122eFcA256541F1ea807eb17e3E529D813
    address damnsterFactoryAdmin = 0x99c368122eFcA256541F1ea807eb17e3E529D813; // TODO 0x99c368122eFcA256541F1ea807eb17e3E529D813
    address taxCollector = 0x99c368122eFcA256541F1ea807eb17e3E529D813; // TODO 0x99c368122eFcA256541F1ea807eb17e3E529D813
    address lpFeeCollector = 0x99c368122eFcA256541F1ea807eb17e3E529D813; // TODO 0x99c368122eFcA256541F1ea807eb17e3E529D813
    address deployer = 0x99c368122eFcA256541F1ea807eb17e3E529D813; // TODO 0x99c368122eFcA256541F1ea807eb17e3E529D813

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("NEO_MAIN_DEPLOYER");
        if(vm.addr(deployerPrivateKey) != deployer) revert("Invalid deployer");
        vm.startBroadcast(deployerPrivateKey);
        console.log("Deployer Address:", vm.addr(deployerPrivateKey));

        //////////////////
        // DEPLOY CTRTS //
        //////////////////

        // 1. locker factory deploy
        address lockerFactoryImpl = address(new LockerFactory());
        address lockerProxy = UnsafeUpgrades.deployTransparentProxy(
            lockerFactoryImpl,
            deployer, // initial admin owner
            abi.encodeCall(LockerFactory.initialize, (lpFeeCollector, deployer))
        );
        lockerFactory = LockerFactory(lockerProxy);

        // 2. damnster factory deploy
        address damnsterFactoryImpl = address(new DamnsterFactory());
        address dmansterProxy = UnsafeUpgrades.deployTransparentProxy(
            damnsterFactoryImpl,
            deployer, // initial admin owner
            abi.encodeCall(DamnsterFactory.initialize, (taxCollector, address(lockerFactory), damnsterFactoryOwner))
        );
        damnsterFactory = DamnsterFactory(payable(dmansterProxy)); // Explicit payable type conversion

        // 3. damnster lens deploy
        // damnsterLens = new DamnsterLens(address(damnsterFactory));

        //////////////////
        // SETTING ARGS //
        //////////////////

        // 1. admin setting
        damnsterFactory.setAdmin(damnsterFactoryAdmin, true);

        //////////////////
        // SETTING TEST //
        //////////////////

        // 1. owner
        require(damnsterFactory.owner() == damnsterFactoryOwner);
        require(lockerFactory.owner() == deployer);

        // 2. fee collector
        require(damnsterFactory.taxCollector() == taxCollector);
        require(lockerFactory.feeRecipient() == lpFeeCollector);

        // 3. admin
        require(damnsterFactory.admins(damnsterFactoryAdmin) == true);

        // 4. holding list
        require(damnsterFactory.holdingAmounts(degen) == type(uint256).max);
        require(damnsterFactory.holdingAmounts(dpad) == type(uint256).max);

        // 5. fee rate
        require(damnsterFactory.taxRate() == 25);
        require(lockerFactory.protocolFee() == 60);

        /////////////////
        //     DONE    //
        /////////////////

        vm.stopBroadcast();
    }
}

// main verify
// forge script script/neo/Damnster.neo.mainnet.s.sol:DamnsterScript --rpc-url $NEO_RPC_URL --broadcast -vvvv --legacy