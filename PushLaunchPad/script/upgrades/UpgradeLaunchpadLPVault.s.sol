// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";

import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {Launchpad} from "contracts/launchpad/Launchpad.sol";
import {LaunchpadLPVault} from "contracts/launchpad/LaunchpadLPVault.sol";
import {ScriptProtector} from "../ScriptProtector.s.sol";

contract UpgradeLaunchpadLPVaultScript is ScriptProtector {
    LaunchpadLPVault launchpadLPVault;
    address launchpad;

    function run() public override /* ensureValidScript */ {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        factory = ERC1967Factory(vm.envAddress("PUSH_FACTORY_TESTNET"));
        launchpadLPVault = LaunchpadLPVault(
            vm.envAddress("PUSH_LAUNCHPAD_LP_VAULT_TESTNET")
        );
        launchpad = vm.envAddress("PUSH_LAUNCHPAD_TESTNET");
        vm.createSelectFork("testnet");

        vm.startBroadcast(deployerPrivateKey);

        address vaultLogic = address(new LaunchpadLPVault());

        // Perform upgrade via low-level call to avoid interface issues in stub
        (bool s, ) = address(factory).call(
            abi.encodeCall(
                ERC1967Factory.upgrade,
                (address(launchpadLPVault), vaultLogic)
            )
        );
        require(s, "upgrade failed");

        vm.stopBroadcast();
    }
}
