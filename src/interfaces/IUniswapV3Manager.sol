// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

contract IUniswapV3Manager {
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    struct MintParams {
        address poolAddress;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }
}
