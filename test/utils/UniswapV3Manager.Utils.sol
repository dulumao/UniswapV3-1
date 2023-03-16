// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./TestUtils.sol";
import "./ERC20Mintable.sol";

import "../../src/lib/LiquidityMath.sol";
import "../../src/interfaces/IUniswapV3Manager.sol";
import "../../src/UniswapV3Factory.sol";
import "../../src/UniswapV3Manager.sol";

contract UniswapV3ManagerUtils is Test, TestUtils {
    struct PoolParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        uint256 currentPrice;
        IUniswapV3Manager.MintParams[] mints;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiquidity;
    }

    struct PoolParamsFull {
        ERC20Mintable token0;
        ERC20Mintable token1;
        uint256 token0Balance;
        uint256 token1Balance;
        uint256 currentPrice;
        IUniswapV3Manager.MintParams[] mints;
        bool mintLiquidity;
        UniswapV3Factory factory;
        UniswapV3Manager manager;
    }

    function setupPool(
        PoolParamsFull memory params
    )
        internal
        returns (
            UniswapV3Pool pool_,
            IUniswapV3Manager.MintParams[] memory mint_,
            uint256 poolBalance0,
            uint256 poolBalance1
        )
    {
        params.token0.mint(address(this), params.token0Balance);
        params.token1.mint(address(this), params.token1Balance);

        pool_ = deployPool(
            params.factory,
            address(params.token0),
            address(params.token1),
            3000,
            params.currentPrice
        );

        if (params.mintLiquidity) {
            params.token0.approve(
                address(params.manager),
                params.token0Balance
            );
            params.token1.approve(
                address(params.manager),
                params.token1Balance
            );

            uint256 poolBalance0Tmp;
            uint256 poolBalance1Tmp;
            for (uint256 i = 0; i < params.mints.length; i++) {
                (poolBalance0Tmp, poolBalance1Tmp) = params.manager.mint(
                    params.mints[i]
                );
                poolBalance0 += poolBalance0Tmp;
                poolBalance1 += poolBalance1Tmp;
            }
        }
        mint_ = params.mints;
    }

    function mintParams(
        ERC20Mintable token0,
        ERC20Mintable token1,
        uint256 lowerPrice,
        uint256 upperPrice,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (IUniswapV3Manager.MintParams memory params) {
        params = mintParams(
            address(token0),
            address(token1),
            lowerPrice,
            upperPrice,
            amount0,
            amount1
        );
    }

    function mintParams(
        IUniswapV3Manager.MintParams memory mint
    ) internal pure returns (IUniswapV3Manager.MintParams[] memory mints) {
        mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mint;
    }

    function mintParams(
        IUniswapV3Manager.MintParams memory mint1,
        IUniswapV3Manager.MintParams memory mint2
    ) internal pure returns (IUniswapV3Manager.MintParams[] memory mints) {
        mints = new IUniswapV3Manager.MintParams[](2);
        mints[0] = mint1;
        mints[1] = mint2;
    }

    function mintParams(
        IUniswapV3Manager.MintParams memory mint1,
        IUniswapV3Manager.MintParams memory mint2,
        IUniswapV3Manager.MintParams memory mint3
    ) internal pure returns (IUniswapV3Manager.MintParams[] memory mints) {
        mints = new IUniswapV3Manager.MintParams[](3);
        mints[0] = mint1;
        mints[1] = mint2;
        mints[2] = mint3;
    }

    function mintParamsToTicks(
        IUniswapV3Manager.MintParams memory mint,
        uint256 currentPrice
    ) internal pure returns (ExpectedTickShort[2] memory ticks) {
        uint128 liq = liquidity(mint, currentPrice);

        ticks[0] = ExpectedTickShort({
            tick: mint.lowerTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: int128(liq)
        });

        ticks[1] = ExpectedTickShort({
            tick: mint.upperTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: -int128(liq)
        });
    }

    function liquidity(
        IUniswapV3Manager.MintParams memory params,
        uint256 currentPrice
    ) internal pure returns (uint128 liquidity_) {
        liquidity_ = LiquidityMath.getLiquidityForAmounts(
            sqrtP(currentPrice),
            sqrtP60FromTick(params.lowerTick),
            sqrtP60FromTick(params.upperTick),
            params.amount0Desired,
            params.amount1Desired
        );
    }
}
