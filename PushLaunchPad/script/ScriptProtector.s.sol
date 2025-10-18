// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";

// Minimal stub to satisfy upgrade scripts during build.
abstract contract ScriptProtector is Script {
    uint256 internal deployerPrivateKey;
    address internal deployer;

    // Common envs that upgrade scripts expect; provide sensible defaults.
    address internal uniV2Router;
    address internal pushRouterProxy;
    address internal clobManagerProxy;
    address internal operatorProxy;
    address internal launchpadProxy;
    address internal bondingCurve;
    ERC1967Factory internal factory;

    modifier SetupScript() {
        // No-op in stub
        _;
    }

    // Provide a virtual run for child scripts to optionally override
    function run() public virtual {}
}
