// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./UniswapV3Pool.sol";

contract UniswapV3Factory is IUniswapV3PoolDeployer {
    PoolParameters public parameters;

    // tickSpacing => pool
    mapping(uint24 => bool) public tickSpacings;
    // token0 => token1 => tickSpacing => pool
    mapping(address => mapping(address => mapping(uint24 => address)))
        public pools;

    constructor() {
        tickSpacings[10] = true;
        tickSpacings[60] = true;
    }

    function createPool(
        address tokenX,
        address tokenY,
        uint24 tickSpacing
    ) public returns (address pool) {
        if (tokenX == tokenY) revert TokensMustBeDifferent();
        if (!tickSpacings[tickSpacing]) revert UnsupportedTickSpacing();

        // Addresses are hashes, and hashes are numbers, so we can say “less than” or “greater that” when comparing addresses
        (tokenX, tokenY) = tokenX < tokenY
            ? (tokenX, tokenY)
            : (tokenY, tokenX);

        if (tokenX == address(0)) revert ZeroAddressNotAllowed();
        if (pools[tokenX][tokenY][tickSpacing] != address(0))
            revert PoolAlreadyExists();

        parameters = PoolParameters({
            factory: address(this),
            token0: tokenX,
            token1: tokenY,
            tickSpacing: tickSpacing
        });

        // EVM has two ways of deploying contracts: via CREATE or via CREATE2 opcode.
        // The only difference between them is how new contract address is generated
        // CREATE2 uses a custom salt to generate a contract address.
        // Factory uses CREATE2 when deploying Pool contracts so pools get unique and
        // deterministic addresses that can be computed in other contracts and off-chain apps.
        // Specifically, for salt, Factory computes a hash keccak256(abi.encodePacked(tokenX, tokenY, tickSpacing))
        pool = address(
            new UniswapV3Pool{
                salt: keccak256(abi.encodePacked(tokenX, tokenY, tickSpacing))
            }()
        );

        // clean up the slot of paramters state variable to reduce gas consumption
        delete parameters;

        // Need to save both in the map
        pools[tokenX][tokenY][tickSpacing] = pool;
        pools[tokenY][tokenX][tickSpacing] = pool;

        emit PoolCreated(tokenX, tokenY, tickSpacing, pool);
    }
}
