// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {Test, stdError} from "forge-std/Test.sol";
import "./ERC20Mintable.sol";

import "../src/lib/LiquidityMath.sol";
import "../src/UniswapV3Manager.sol";
import "./UniswapV3Manager.Utils.t.sol";

contract UniswapV3ManagerTest is Test, UniswapV3ManagerUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;
    UniswapV3Manager manager;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;
    bytes extra;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
        manager = new UniswapV3Manager();
        extra = encodeExtra(address(token0), address(token1), address(this));
    }

    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            sqrtP(params.currentPrice),
            tick(params.currentPrice)
        );

        if (params.mintLiquidity) {
            token0.approve(address(manager), params.wethBalance);
            token1.approve(address(manager), params.usdcBalance);

            uint256 poolBalance0Tmp;
            uint256 poolBalance1Tmp;

            for (uint256 i = 0; i < params.mints.length; i++) {
                params.mints[i].poolAddress = address(pool);
                (poolBalance0Tmp, poolBalance1Tmp) = manager.mint(
                    params.mints[i]
                );
                poolBalance0 += poolBalance0Tmp;
                poolBalance1 += poolBalance1Tmp;
            }
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
    }

    function testMintInRange() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        setupTestCase(params);

        uint256 expectedAmount0 = 0.998995580131581600 ether;
        uint256 expectedAmount1 = 4999.999999999999999999 ether;

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                positionLiquidity: liquidity(mints[0], 5000),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintRangeBelow() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4000, 4999, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        setupTestCase(params);

        uint256 expectedAmount0 = 0 ether;
        uint256 expectedAmount1 = 4999.999999999999999997 ether;

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                positionLiquidity: liquidity(mints[0], 5000),
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintRangeAbove() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(5001, 6250, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        setupTestCase(params);

        uint256 expectedAmount0 = 1 ether;
        uint256 expectedAmount1 = 0 ether;

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                positionLiquidity: liquidity(mints[0], 5000),
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintOverlappingRanges() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](2);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        mints[1] = mintParams(
            4000,
            6250,
            (1 ether * 75) / 100,
            (5000 ether * 75) / 100
        );
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 3 ether,
            usdcBalance: 15000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        setupTestCase(params);

        uint256 expectedAmount0 = 1.748692227462822454 ether;
        uint256 expectedAmount1 = 8749.999999999999999999 ether;

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                positionLiquidity: liquidity(mints[0], 5000),
                currentLiquidity: liquidity(mints[0], 5000) +
                    liquidity(mints[1], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[1].lowerTick,
                upperTick: mints[1].upperTick,
                positionLiquidity: liquidity(mints[1], 5000),
                currentLiquidity: liquidity(mints[0], 5000) +
                    liquidity(mints[1], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintPartiallyOverlappingRanges() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](3);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        mints[1] = mintParams(
            4000,
            4999,
            (1 ether * 75) / 100,
            (5000 ether * 75) / 100
        );
        mints[2] = mintParams(
            5001,
            6250,
            (1 ether * 50) / 100,
            (5000 ether * 50) / 100
        );
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 3 ether,
            usdcBalance: 15000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        setupTestCase(params);

        uint256 expectedAmount0 = 1.498995580131581600 ether;
        uint256 expectedAmount1 = 8749.999999999999999993 ether;

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                positionLiquidity: liquidity(mints[0], 5000),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[1].lowerTick,
                upperTick: mints[1].upperTick,
                positionLiquidity: liquidity(mints[1], 5000),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[2].lowerTick,
                upperTick: mints[2].upperTick,
                positionLiquidity: liquidity(mints[2], 5000),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintInvalidTickRangeLower() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );
        manager = new UniswapV3Manager();

        vm.expectRevert(encodeError("InvalidTickRange()"));
        manager.mint(
            IUniswapV3Manager.MintParams({
                poolAddress: address(pool),
                lowerTick: -887273,
                upperTick: 0,
                amount0Desired: 0,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function testMintInvalidTickRangeUpper() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );
        manager = new UniswapV3Manager();

        vm.expectRevert(encodeError("InvalidTickRange()"));
        manager.mint(
            IUniswapV3Manager.MintParams({
                poolAddress: address(pool),
                lowerTick: 0,
                upperTick: 887273,
                amount0Desired: 0,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function testMintZeroLiquidity() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );
        manager = new UniswapV3Manager();

        vm.expectRevert(encodeError("ZeroLiquidity()"));
        manager.mint(
            IUniswapV3Manager.MintParams({
                poolAddress: address(pool),
                lowerTick: 0,
                upperTick: 1,
                amount0Desired: 0,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function testMintInsufficientTokenBalance() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 0 ether,
            usdcBalance: 0 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: false,
            transferInSwapCallback: true,
            mintLiquidity: false
        });
        setupTestCase(params);
        mints[0].poolAddress = address(pool);

        vm.expectRevert(stdError.arithmeticError);
        manager.mint(mints[0]);
    }

    function testMintSlippageProtection() public {
        uint256 amount0 = 1 ether;
        uint256 amount1 = 5000 ether;
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            sqrtP(5000),
            tick(5000)
        );

        token0.mint(address(this), amount0);
        token0.approve(address(manager), amount0);

        token1.mint(address(this), amount1);
        token1.approve(address(manager), amount1);

        vm.expectRevert(
            encodeSlippageCheckFailed(
                0.998995580131581600 ether,
                4999.999999999999999999 ether
            )
        );

        manager.mint(
            IUniswapV3Manager.MintParams({
                poolAddress: address(pool),
                lowerTick: tick(4545),
                upperTick: tick(5500),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0,
                amount1Min: amount1
            })
        );

        manager.mint(
            IUniswapV3Manager.MintParams({
                poolAddress: address(pool),
                lowerTick: tick(4545),
                upperTick: tick(5500),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: (amount0 * 99) / 100,
                amount1Min: (amount1 * 99) / 100
            })
        );
    }

    function testSwapBuyEth() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);

        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 42 ether; // 42 USDC
        token1.mint(address(this), swapAmount);
        token1.approve(address(manager), swapAmount);

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));
        int256 userBalance1Before = int256(token1.balanceOf(address(this)));

        (int256 amount0Delta, int256 amount1Delta) = manager.swap(
            address(pool),
            false,
            swapAmount,
            sqrtP(5004),
            extra
        );

        assertEq(amount0Delta, -0.008396874645169943 ether, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: token0,
                token1: token1,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5604415652688968742392013927525, // 5003.8180249710795
                tick: 85183,
                currentLiquidity: liquidity(mints[0], 5000)
            })
        );
    }

    function testSwapBuyUsdc() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);

        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 0.01337 ether; // 0.01337 ether
        token1.mint(address(this), swapAmount);
        token1.approve(address(manager), swapAmount);

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));
        int256 userBalance1Before = int256(token1.balanceOf(address(this)));

        (int256 amount0Delta, int256 amount1Delta) = manager.swap(
            address(pool),
            false,
            swapAmount,
            sqrtP(4993),
            extra
        );

        assertEq(amount0Delta, 0.01337 ether, "invalid ETH in");
        assertEq(
            amount1Delta,
            -66.807123823853842027 ether,
            "invalid USDC out"
        );

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: token0,
                token1: token1,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5598737223630966236662554421688, // 5003.8180249710795
                tick: 85163,
                currentLiquidity: liquidity(mints[0], 5000)
            })
        );
    }

    function testSwapMixed() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);

        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 ethAmount = 0.01337 ether; // 0.01337 ether
        token1.mint(address(this), ethAmount);
        token1.approve(address(manager), ethAmount);

        uint256 usdcAmount = 55 ether; // 55 USDC
        token1.mint(address(this), usdcAmount);
        token1.approve(address(manager), usdcAmount);

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));
        int256 userBalance1Before = int256(token1.balanceOf(address(this)));

        (int256 amount0Delta1, int256 amount1Delta1) = manager.swap(
            address(pool),
            false,
            ethAmount,
            sqrtP(4990),
            extra
        );

        (int256 amount0Delta2, int256 amount1Delta2) = manager.swap(
            address(pool),
            false,
            usdcAmount,
            sqrtP(5004),
            extra
        );

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: token0,
                token1: token1,
                userBalance0: uint256(
                    userBalance0Before - amount0Delta1 - amount0Delta2
                ),
                userBalance1: uint256(
                    userBalance1Before - amount1Delta1 - amount1Delta2
                ),
                poolBalance0: uint256(
                    int256(poolBalance0) + amount0Delta1 + amount0Delta2
                ),
                poolBalance1: uint256(
                    int256(poolBalance1) + amount1Delta1 + amount1Delta2
                ),
                sqrtPriceX96: 5601607565086694240599300641950, // 5003.8180249710795
                tick: 85173,
                currentLiquidity: liquidity(mints[0], 5000)
            })
        );
    }

    function testSwapBuyEthNotEnoughLiquidity() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);

        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        setupTestCase(params);

        uint256 swapAmount = 5300 ether;
        token1.mint(address(this), swapAmount);
        token1.approve(address(manager), swapAmount);

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        manager.swap(address(pool), false, swapAmount, 0, extra);
    }

    function testSwapBuyUsdcNotEnoughLiquidity() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);

        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiquidity: true
        });
        setupTestCase(params);

        uint256 swapAmount = 1.1 ether;
        token1.mint(address(this), swapAmount);
        token1.approve(address(manager), swapAmount);

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        manager.swap(address(pool), true, swapAmount, 0, extra);
    }

    function testSwapInsufficientInputAmount() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);

        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: false,
            mintLiquidity: true
        });
        setupTestCase(params);

        vm.expectRevert(stdError.arithmeticError);
        manager.swap(address(pool), false, 42 ether, sqrtP(5010), extra);
    }
}
