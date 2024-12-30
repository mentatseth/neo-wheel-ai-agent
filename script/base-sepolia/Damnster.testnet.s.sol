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

    // test wallet
    address taxCollector = 0xefa0Da5FdEdE00A48B314d1872F0e3c5aeA49cB3;
    address lpFeeCollector = 0x9f32011CA5C7F46e8D56a7De7dB9a1491F52761C;
    address deployer = 0xa63e884DF12aC7C6fa80B38Ce035fe770b18661f;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DAMNSTER_TEST_DEPLOYER");
        if(vm.addr(deployerPrivateKey) != deployer) revert("Invalid deployer");
        vm.startBroadcast(deployerPrivateKey);
        console.log("Deployer Address:", vm.addr(deployerPrivateKey));

        address lockerFactoryImpl = address(new LockerFactory());
        address lockerProxy = UnsafeUpgrades.deployTransparentProxy(
            lockerFactoryImpl,
            deployer,
            abi.encodeCall(LockerFactory.initialize, (lpFeeCollector, deployer))
        );
        lockerFactory = LockerFactory(lockerProxy);


        address damnsterFactoryImpl = address(new DamnsterFactory());

        address dmansterProxy = UnsafeUpgrades.deployTransparentProxy(
            damnsterFactoryImpl,
            deployer, // initial admin owner
            abi.encodeCall(DamnsterFactory.initialize, (taxCollector, address(lockerFactory), deployer))
        );
        damnsterFactory = DamnsterFactory(payable(dmansterProxy)); // Explicit payable type conversion

        //Note setting for testnet
        damnsterFactory.updateHoldingAmounts(address(damnsterFactory.DEGEN()), 0);
        damnsterFactory.updateHoldingAmounts(address(damnsterFactory.DPAD()), 0);

        damnsterLens = new DamnsterLens(address(damnsterFactory));

        vm.stopBroadcast();
    }
}

// forge script --chain sepolia script/Damnster.testnet.s.sol:DamnsterScript --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv --legacy