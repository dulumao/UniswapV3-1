// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

interface IUniswapV3PoolDeployer {
    error PoolAlreadyExists();
    error ZeroAddressNotAllowed();
    error TokensMustBeDifferent();
    error UnsupportedFee();

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed tickSpacing,
        address pool
    );

    struct PoolParameters {
        address factory;
        address token0;
        address token1;
        uint24 tickSpacing;
        uint24 fee;
    }

    function parameters()
        external
        returns (
            address factory,
            address token0,
            address token1,
            uint24 tickSpacing,
            uint24 fee
        );
}
