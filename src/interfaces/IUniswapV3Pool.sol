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

    ////////////////////////////////////////////
    ///////////////   Functions    /////////////
    ////////////////////////////////////////////
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick);

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
        bytes calldata data
    ) external returns (int256, int256);
}
