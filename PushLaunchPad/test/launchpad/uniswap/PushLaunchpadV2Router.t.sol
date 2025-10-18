// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {PushLaunchpadV2Router2} from "../../../src/launchpad/uniswap/PushLaunchpadV2Router2.sol";
import {PushLaunchpadV2PairFactory} from "../../../src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol";
import {PushLaunchpadV2Pair} from "../../../src/launchpad/uniswap/PushLaunchpadV2Pair.sol";
import {IWETH} from "../../../src/launchpad/uniswap/interfaces/IWETH.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        deposit();
    }
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

/**
 * @title PushLaunchpadV2RouterTest
 * @notice Comprehensive tests for the upgraded 0.8.27 routers
 */
contract PushLaunchpadV2RouterTest is Test {
    PushLaunchpadV2Router2 router;
    PushLaunchpadV2PairFactory factory;
    MockWETH weth;
    MockERC20 tokenA;
    MockERC20 tokenB;

    address alice = address(0x1);
    address bob = address(0x2);
    address feeToSetter = address(0x3);

    function setUp() public {
        // Deploy WETH
        weth = new MockWETH();

        // Deploy Factory
        factory = new PushLaunchpadV2PairFactory(
            feeToSetter,
            address(0), // launchpad
            address(0), // launchpadLp
            address(0) // launchpadFeeDistributor
        );

        // Deploy Router
        router = new PushLaunchpadV2Router2(address(factory), address(weth));

        // Deploy test tokens
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");

        // Ensure tokenA < tokenB for Uniswap V2
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        tokenA.mint(alice, 1000 ether);
        tokenB.mint(alice, 1000 ether);
        tokenA.mint(bob, 1000 ether);
        tokenB.mint(bob, 1000 ether);
    }

    function testFactoryAddress() public view {
        assertEq(router.factory(), address(factory));
    }

    function testWETHAddress() public view {
        assertEq(router.WETH(), address(weth));
    }

    function testAddLiquidity() public {
        vm.startPrank(alice);

        uint256 amountADesired = 100 ether;
        uint256 amountBDesired = 100 ether;
        uint256 amountAMin = 90 ether;
        uint256 amountBMin = 90 ether;

        // Approve router
        tokenA.approve(address(router), amountADesired);
        tokenB.approve(address(router), amountBDesired);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                alice,
                block.timestamp
            );

        vm.stopPrank();

        // Assertions
        assertGt(amountA, 0, "Amount A should be greater than 0");
        assertGt(amountB, 0, "Amount B should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        // Check pair was created
        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertNotEq(pair, address(0), "Pair should be created");

        console2.log("Added liquidity - Amount A:", amountA);
        console2.log("Added liquidity - Amount B:", amountB);
        console2.log("Added liquidity - Liquidity:", liquidity);
    }

    function testRemoveLiquidity() public {
        // First add liquidity
        vm.startPrank(alice);

        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);

        (, , uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            0,
            0,
            alice,
            block.timestamp
        );

        // Get pair contract
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        PushLaunchpadV2Pair pair = PushLaunchpadV2Pair(pairAddress);

        // Approve router to spend LP tokens
        pair.approve(address(router), liquidity);

        // Remove liquidity
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            alice,
            block.timestamp
        );

        vm.stopPrank();

        assertGt(amountA, 0, "Should receive token A");
        assertGt(amountB, 0, "Should receive token B");

        console2.log("Removed liquidity - Amount A:", amountA);
        console2.log("Removed liquidity - Amount B:", amountB);
    }

    function testSwapExactTokensForTokens() public {
        // Add liquidity first
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        // Now swap
        vm.startPrank(bob);

        uint256 amountIn = 1 ether;
        uint256 amountOutMin = 0.9 ether;

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 balanceBefore = tokenB.balanceOf(bob);

        tokenA.approve(address(router), amountIn);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            bob,
            block.timestamp
        );

        uint256 balanceAfter = tokenB.balanceOf(bob);

        vm.stopPrank();

        assertEq(amounts[0], amountIn, "Input amount should match");
        assertGt(amounts[1], amountOutMin, "Output should be greater than min");
        assertEq(
            balanceAfter - balanceBefore,
            amounts[1],
            "Balance increase should match output"
        );

        console2.log("Swap - Amount In:", amounts[0]);
        console2.log("Swap - Amount Out:", amounts[1]);
    }

    function testSwapTokensForExactTokens() public {
        // Add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        // Swap for exact output
        vm.startPrank(bob);

        uint256 amountOut = 1 ether;
        uint256 amountInMax = 2 ether;

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        tokenA.approve(address(router), amountInMax);

        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            bob,
            block.timestamp
        );

        vm.stopPrank();

        assertLt(amounts[0], amountInMax, "Input should be less than max");
        assertEq(amounts[1], amountOut, "Output should match exact amount");

        console2.log("Swap Exact Out - Amount In:", amounts[0]);
        console2.log("Swap Exact Out - Amount Out:", amounts[1]);
    }

    function testAddLiquidityETH() public {
        vm.startPrank(alice);

        uint256 tokenAmount = 10 ether;
        uint256 ethAmount = 10 ether;

        tokenA.approve(address(router), tokenAmount);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router
            .addLiquidityETH{value: ethAmount}(
            address(tokenA),
            tokenAmount,
            0,
            0,
            alice,
            block.timestamp
        );

        vm.stopPrank();

        assertGt(amountToken, 0, "Token amount should be greater than 0");
        assertGt(amountETH, 0, "ETH amount should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        console2.log("Added ETH liquidity - Token:", amountToken);
        console2.log("Added ETH liquidity - ETH:", amountETH);
        console2.log("Added ETH liquidity - Liquidity:", liquidity);
    }

    function testRemoveLiquidityETH() public {
        // Add liquidity first
        vm.startPrank(alice);

        tokenA.approve(address(router), 10 ether);

        (, , uint256 liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10 ether,
            0,
            0,
            alice,
            block.timestamp
        );

        // Get pair and approve
        address pairAddress = factory.getPair(address(tokenA), address(weth));
        PushLaunchpadV2Pair pair = PushLaunchpadV2Pair(pairAddress);
        pair.approve(address(router), liquidity);

        // Remove liquidity
        (uint256 amountToken, uint256 amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            0,
            0,
            alice,
            block.timestamp
        );

        vm.stopPrank();

        assertGt(amountToken, 0, "Should receive tokens");
        assertGt(amountETH, 0, "Should receive ETH");

        console2.log("Removed ETH liquidity - Token:", amountToken);
        console2.log("Removed ETH liquidity - ETH:", amountETH);
    }

    function testSwapExactETHForTokens() public {
        // Add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 ether);
        router.addLiquidityETH{value: 100 ether}(
            address(tokenA),
            100 ether,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        // Swap ETH for tokens
        vm.startPrank(bob);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        uint256 balanceBefore = tokenA.balanceOf(bob);

        uint256[] memory amounts = router.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            bob,
            block.timestamp
        );

        uint256 balanceAfter = tokenA.balanceOf(bob);

        vm.stopPrank();

        assertEq(amounts[0], 1 ether, "Input should be 1 ETH");
        assertGt(amounts[1], 0, "Should receive tokens");
        assertEq(
            balanceAfter - balanceBefore,
            amounts[1],
            "Balance should increase"
        );

        console2.log("Swap ETH for tokens - ETH in:", amounts[0]);
        console2.log("Swap ETH for tokens - Tokens out:", amounts[1]);
    }

    function testSwapTokensForExactETH() public {
        // Add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 ether);
        router.addLiquidityETH{value: 100 ether}(
            address(tokenA),
            100 ether,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        // Swap tokens for exact ETH
        vm.startPrank(bob);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        uint256 ethOut = 1 ether;
        tokenA.approve(address(router), 10 ether);

        uint256 ethBalanceBefore = bob.balance;

        uint256[] memory amounts = router.swapTokensForExactETH(
            ethOut,
            10 ether,
            path,
            bob,
            block.timestamp
        );

        uint256 ethBalanceAfter = bob.balance;

        vm.stopPrank();

        assertLt(amounts[0], 10 ether, "Input should be less than max");
        assertEq(amounts[1], ethOut, "Should receive exact ETH");
        assertEq(
            ethBalanceAfter - ethBalanceBefore,
            ethOut,
            "ETH balance should increase"
        );

        console2.log("Swap tokens for exact ETH - Tokens in:", amounts[0]);
        console2.log("Swap tokens for exact ETH - ETH out:", amounts[1]);
    }

    function test_RevertWhen_ExpiredDeadline() public {
        vm.startPrank(alice);

        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);

        // Use past timestamp (should revert)
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            0,
            0,
            alice,
            block.timestamp - 1
        );

        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientOutputAmount() public {
        // Add normal liquidity
        vm.startPrank(alice);

        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        // Try to swap with unrealistic minimum output
        vm.startPrank(bob);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        tokenA.approve(address(router), 1 ether);

        // This should revert due to insufficient output amount
        // Swapping 1 token cannot give you 99 tokens with 1:1 liquidity
        vm.expectRevert(bytes("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"));
        router.swapExactTokensForTokens(
            1 ether,
            99 ether, // Unrealistic min output
            path,
            bob,
            block.timestamp
        );

        vm.stopPrank();
    }

    function testGetAmountsOut() public {
        // Add liquidity first so getAmountsOut can calculate
        vm.startPrank(alice);
        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        // Now test the library functions work correctly
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256[] memory amounts = router.getAmountsOut(1 ether, path);

        assertEq(amounts.length, 2, "Should return 2 amounts");
        assertEq(amounts[0], 1 ether, "First amount should be input");
        assertGt(amounts[1], 0, "Output should be greater than 0");

        console2.log("GetAmountsOut - Input:", amounts[0]);
        console2.log("GetAmountsOut - Output:", amounts[1]);
    }

    function testQuote() public view {
        uint256 quote = router.quote(1 ether, 100 ether, 100 ether);
        assertEq(quote, 1 ether, "Quote should be 1:1 for equal reserves");

        quote = router.quote(1 ether, 100 ether, 200 ether);
        assertEq(quote, 2 ether, "Quote should be 2:1 for 2x reserves");
    }

    function testGetAmountOut() public view {
        uint256 amountOut = router.getAmountOut(1 ether, 100 ether, 100 ether);
        assertGt(amountOut, 0, "Amount out should be greater than 0");
        assertLt(
            amountOut,
            1 ether,
            "Amount out should be less than input due to fee"
        );
    }

    function testGetAmountIn() public view {
        uint256 amountIn = router.getAmountIn(1 ether, 100 ether, 100 ether);
        assertGt(
            amountIn,
            1 ether,
            "Amount in should be greater than output due to fee"
        );
    }
}
