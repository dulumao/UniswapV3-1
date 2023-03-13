// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

import "../UniswapV3Pool.sol";

// A library that will help us calculate pool contract addresses from other contracts
// First, we calculate salt (abi.encodePacked(token0, token1, tickSpacing)) and hash it.
// then, we obtain Pool contract code (type(UniswapV3Pool).creationCode) and also hash it
// then, we build a sequence of bytes that includes: 0xff, Factory contract address, hashed salt, and hashed Pool contract code
// we then hash the sequence and convert it to an address
// These steps implement contract address generation as it’s defined in https://eips.ethereum.org/EIPS/eip-1014
library PoolAddress {
    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 fee
    ) internal pure returns (address pool) {
        require(token0 < token1);

        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1, fee)),
                            keccak256(type(UniswapV3Pool).creationCode)
                        )
                    )
                )
            )
        );
    }
}
