// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./utils/ERC20Mintable.sol";
import "./utils/UniswapV3Pool.Utils.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/lib/LiquidityMath.sol";
import "../src/lib/TickMath.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3PoolSwapsTest is Test, UniswapV3PoolUtils {
    ERC20Mintable weth;
    ERC20Mintable usdc;
    UniswapV3Factory factory;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;
    bytes extra;

    function setUp() public {
        usdc = new ERC20Mintable("USDC", "USDC", 18);
        weth = new ERC20Mintable("Ether", "ETH", 18);
        factory = new UniswapV3Factory();

        extra = encodeExtra(address(weth), address(usdc), address(this));
    }

    function testInitialize() public {
        pool = UniswapV3Pool(
            factory.createPool(address(weth), address(usdc), 3000)
        );

        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext
        ) = pool.slot0();
        assertEq(sqrtPriceX96, 0, "invalid sqrtPriceX96");
        assertEq(tick, 0, "invalid tick");
        assertEq(observationIndex, 0, "invalid observation index");
        assertEq(observationCardinality, 0, "invalid observation cardinality");
        assertEq(
            observationCardinalityNext,
            0,
            "invalid next observation cardinality"
        );

        pool.initialize(sqrtP(31337));

        (
            sqrtPriceX96,
            tick,
            observationIndex,
            observationCardinality,
            observationCardinalityNext
        ) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            14025175117687921942002399182848,
            "invalid sqrtPriceX96"
        );
        assertEq(tick, 103530, "invalid tick");
        assertEq(observationIndex, 0, "invalid observation index");
        assertEq(observationCardinality, 1, "invalid observation cardinality");
        assertEq(
            observationCardinalityNext,
            1,
            "invalid next observation cardinality"
        );

        vm.expectRevert(encodeError("AlreadyInitialized()"));
        pool.initialize(sqrtP(42));
    }

    //  One price range
    //
    //          5000
    //  4545 -----|----- 5500
    //
    // function testBuyEthOnePriceRange() public {
    //     (
    //         LiquidityRange[] memory liquidity,
    //         uint256 poolBalance0,
    //         uint256 poolBalance1
    //     ) = setupPool(
    //             PoolParams({
    //                 balances: [uint256(1 ether), 5000 ether],
    //                 currentPrice: 5000,
    //                 liquidity: liquidityRanges(
    //                     liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000)
    //                 ),
    //                 transferInMintCallback: true,
    //                 transferInSwapCallback: true,
    //                 mintLiquidity: true
    //             })
    //         );

    //     uint256 swapAmount = 42 ether; // 42 USDC
    //     usdc.mint(address(this), swapAmount);
    //     usdc.approve(address(this), swapAmount);

    //     (int256 userBalance0Before, int256 userBalance1Before) = (
    //         int256(weth.balanceOf(address(this))),
    //         int256(usdc.balanceOf(address(this)))
    //     );

    //     (int256 amount0Delta, int256 amount1Delta) = pool.swap(
    //         address(this),
    //         false,
    //         swapAmount,
    //         sqrtP(5004),
    //         extra
    //     );

    //     assertEq(amount0Delta, -0.008371593947078467 ether, "invalid ETH out");
    //     assertEq(amount1Delta, 42 ether, "invalid USDC in");

    //     LiquidityRange memory liq = liquidity[0];
    //     assertMany(
    //         ExpectedMany({
    //             pool: pool,
    //             tokens: [weth, usdc],
    //             liquidity: liq.amount,
    //             sqrtPriceX96: 5604422590555458105735383351329, // 5003.830413717752
    //             tick: 85183,
    //             fees: [
    //                 uint256(0),
    //                 27727650748765949686643356806934465 // 0.000081484242041869
    //             ],
    //             userBalances: [
    //                 uint256(userBalance0Before - amount0Delta),
    //                 uint256(userBalance1Before - amount1Delta)
    //             ],
    //             poolBalances: [
    //                 uint256(int256(poolBalance0) + amount0Delta),
    //                 uint256(int256(poolBalance1) + amount1Delta)
    //             ],
    //             position: ExpectedPositionShort({
    //                 ticks: [liq.lowerTick, liq.upperTick],
    //                 liquidity: liq.amount,
    //                 feeGrowth: [uint256(0), 0],
    //                 tokensOwed: [uint128(0), 0]
    //             }),
    //             ticks: rangeToTicks(liq),
    //             observation: ExpectedObservationShort({
    //                 index: 0,
    //                 timestamp: 1,
    //                 tickCummulative: 0,
    //                 initialized: true
    //             })
    //         })
    //     );
    // }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function setupPool(
        PoolParams memory params
    )
        internal
        returns (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        )
    {
        weth.mint(address(this), params.balances[0]);
        usdc.mint(address(this), params.balances[1]);

        pool = deployPool(
            factory,
            address(weth),
            address(usdc),
            3000,
            params.currentPrice
        );

        if (params.mintLiquidity) {
            weth.approve(address(this), params.balances[0]);
            usdc.approve(address(this), params.balances[1]);

            uint256 poolBalance0Tmp;
            uint256 poolBalance1Tmp;
            for (uint256 i = 0; i < params.liquidity.length; i++) {
                (poolBalance0Tmp, poolBalance1Tmp) = pool.mint(
                    address(this),
                    params.liquidity[i].lowerTick,
                    params.liquidity[i].upperTick,
                    params.liquidity[i].amount,
                    extra
                );
                poolBalance0 += poolBalance0Tmp;
                poolBalance1 += poolBalance1Tmp;
            }
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
        liquidity = params.liquidity;
    }
}
