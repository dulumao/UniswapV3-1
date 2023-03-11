// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./UniswapV3Pool.sol";

contract UniswapV3Factory is IUniswapV3PoolDeployer {
    PoolParameters public parameters;

    // fees => tickSpacing
    mapping(uint24 => uint24) public fees;
    // token0 => token1 => fee => pool
    mapping(address => mapping(address => mapping(uint24 => address)))
        public pools;

    constructor() {
        // Fee amounts are hundredths of the basis point. That is, 1 fee unit is 0.0001%, 500 is 0.05%, and 3000 is 0.3%.
        fees[500] = 10;
        fees[3000] = 60;
    }

    function createPool(
        address tokenX,
        address tokenY,
        uint24 fee
    ) public returns (address pool) {
        if (tokenX == tokenY) revert TokensMustBeDifferent();
        if (fees[fee] == 0) revert UnsupportedFee();

        // Addresses are hashes, and hashes are numbers, so we can say “less than” or “greater that” when comparing addresses
        (tokenX, tokenY) = tokenX < tokenY
            ? (tokenX, tokenY)
            : (tokenY, tokenX);

        if (tokenX == address(0)) revert ZeroAddressNotAllowed();
        if (pools[tokenX][tokenY][fee] != address(0))
            revert PoolAlreadyExists();

        parameters = PoolParameters({
            factory: address(this),
            token0: tokenX,
            token1: tokenY,
            tickSpacing: fees[fee],
            fee: fee
        });

        // EVM has two ways of deploying contracts: via CREATE or via CREATE2 opcode.
        // The only difference between them is how new contract address is generated
        // CREATE2 uses a custom salt to generate a contract address.
        // Factory uses CREATE2 when deploying Pool contracts so pools get unique and
        // deterministic addresses that can be computed in other contracts and off-chain apps.
        // Specifically, for salt, Factory computes a hash keccak256(abi.encodePacked(tokenX, tokenY, fee))
        pool = address(
            new UniswapV3Pool{
                salt: keccak256(abi.encodePacked(tokenX, tokenY, fee))
            }()
        );

        // clean up the slot of paramters state variable to reduce gas consumption
        delete parameters;

        // Need to save both in the map
        pools[tokenX][tokenY][fee] = pool;
        pools[tokenY][tokenX][fee] = pool;

        emit PoolCreated(tokenX, tokenY, fee, pool);
    }
}
