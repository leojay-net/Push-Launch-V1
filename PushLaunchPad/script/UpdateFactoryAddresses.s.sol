// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PushLaunchpadV2PairFactory} from "../src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol";

/**
 * @title UpdateFactoryAddresses
 * @notice Script to update launchpad addresses in the factory after deployment
 * @dev This enables special fee-enabled pairs for launchpad-graduated tokens
 *
 * Usage:
 *   forge script script/UpdateFactoryAddresses.s.sol:UpdateFactoryAddresses \
 *     --rpc-url push_testnet \
 *     --broadcast \
 *     -vvv
 *
 * Environment variables required:
 *   - PRIVATE_KEY: Private key of the feeToSetter account
 *   - FACTORY_ADDRESS: Address of deployed PushLaunchpadV2PairFactory
 *   - LAUNCHPAD_ADDRESS: Address of deployed Launchpad proxy
 *   - LP_VAULT_ADDRESS: Address of deployed LaunchpadLPVault
 *   - DISTRIBUTOR_ADDRESS: Address of deployed Distributor
 */
contract UpdateFactoryAddresses is Script {
    function run() public {
        // Load addresses from environment
        address factory = vm.envAddress("FACTORY_ADDRESS");
        address launchpad = vm.envAddress("LAUNCHPAD_ADDRESS");
        address lpVault = vm.envAddress("LP_VAULT_ADDRESS");
        address distributor = vm.envAddress("DISTRIBUTOR_ADDRESS");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        console2.log("=== Updating Factory Launchpad Addresses ===");
        console2.log("Factory:", factory);
        console2.log("Launchpad:", launchpad);
        console2.log("LP Vault:", lpVault);
        console2.log("Distributor:", distributor);

        vm.startBroadcast(privateKey);

        // Update the factory with launchpad addresses
        PushLaunchpadV2PairFactory(factory).setLaunchpadAddresses(
            launchpad,
            lpVault,
            distributor
        );

        vm.stopBroadcast();

        // Verify the update
        address storedLaunchpad = PushLaunchpadV2PairFactory(factory)
            .launchpad();
        address storedLpVault = PushLaunchpadV2PairFactory(factory)
            .launchpadLp();
        address storedDistributor = PushLaunchpadV2PairFactory(factory)
            .launchpadFeeDistributor();

        console2.log("\n=== Verification ===");
        console2.log("Stored Launchpad:", storedLaunchpad);
        console2.log("Stored LP Vault:", storedLpVault);
        console2.log("Stored Distributor:", storedDistributor);

        require(storedLaunchpad == launchpad, "Launchpad address mismatch");
        require(storedLpVault == lpVault, "LP Vault address mismatch");
        require(
            storedDistributor == distributor,
            "Distributor address mismatch"
        );

        console2.log("\n[SUCCESS] Factory addresses updated successfully!");
        console2.log(
            "Launchpad-created pairs will now have special fee distribution."
        );
    }
}
