// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

interface IUniswapV3Pool {
    ////////////////////////////////////////////
    ///////////////    Errors    ///////////////
    ////////////////////////////////////////////
    error InvalidTickRange();
    error ZeroLiquidity();
    error InsufficientInputAmount();
    error NotEnoughLiquidity();
    error InvalidPriceLimit();

    ////////////////////////////////////////////
    ///////////////    Events    ///////////////
    ////////////////////////////////////////////
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    event Flash(address indexed recipient, uint256 amount0, uint256 amount1);

    ////////////////////////////////////////////
    ///////////////   Structs    /////////////
    ////////////////////////////////////////////

    // Structs
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    struct Slot0 {
        // current sqrt(P)
        uint160 sqrtPriceX96;
        // current tick
        int24 tick;
    }

    // maintain current swap's state
    struct SwapState {
        uint256 amountSpecifiedRemaining;
        uint256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
    }

    // tracks the state of one iteration of an “order filling”
    struct StepState {
        uint160 sqrtPriceStartX96;
        int24 nextTick;
        bool initialized;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
    }

    ////////////////////////////////////////////
    ///////////////   Functions    /////////////
    ////////////////////////////////////////////
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256, uint256);

    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256, int256);
}
