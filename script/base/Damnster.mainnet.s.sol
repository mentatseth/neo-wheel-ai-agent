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

    address degen = 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed;
    address dpad = 0x1234d66B6FBb900296AE2F57740b800fd8960927;

    // wallet
    address damnsterFactoryOwner; // TODO 0xb406813fdc3Bd7f10e4F67b8f2fB2D7960A5169e
    address damnsterFactoryAdmin; // TODO 0xD5C099fFafB874Cf05784B00C85F87caDA9fe6be
    address taxCollector; // TODO 0xD5C099fFafB874Cf05784B00C85F87caDA9fe6be
    address lpFeeCollector; // TODO 0xD5C099fFafB874Cf05784B00C85F87caDA9fe6be
    address deployer; // TODO 0xb406813fdc3Bd7f10e4F67b8f2fB2D7960A5169e

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DAMNSTER_MAIN_DEPLOYER");
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
        damnsterLens = new DamnsterLens(address(damnsterFactory));

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
        require(damnsterFactory.holdingAmounts(degen) == 10_000 ether);
        require(damnsterFactory.holdingAmounts(dpad) == 1_000 ether);

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
// forge script script/base/Damnster.mainnet.s.sol:DamnsterScript --rpc-url $BASE_RPC_URL --broadcast -vvvv --legacy --verify --etherscan-api-key $DAMNSTER_MAIN_ETHERSCAN_API --watch

// lp locker verify
// forge verify-contract 0xf0ACAddD170d627784091DD005E31C57dBc6C4cd LpLocker --rpc-url $BASE_RPC_URL --etherscan-api-key $DAMNSTER_MAIN_ETHERSCAN_API --watch --constructor-args $(cast abi-encode "constructor(address, address, address, uint64, uint256, address)" 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1 0x3f4621583CdEeBcFd0A14eecbabA78AfCd999457 0x07c7C608b15095a507D7d2f641216030f884c188 33291961200 60 0xD5C099fFafB874Cf05784B00C85F87caDA9fe6be)

// token verify
// forge verify-contract 0x19F803925f28aEcA0E2d276cfE7dC6330EAB0245 DamnsterToken --rpc-url $BASE_RPC_URL --etherscan-api-key $DAMNSTER_MAIN_ETHERSCAN_API --watch --constructor-args $(cast abi-encode "constructor(string memory, string memory, uint256, address, uint256, string memory, string memory)" "Merry Degen Christmast Jacek" "MDCJ" 100000000000000000000000000000 0x07c7C608b15095a507D7d2f641216030f884c188 398678 "" "0x4a32bdeb6b7cd3bbdcef7b850a6e9cbcc4018a76")

