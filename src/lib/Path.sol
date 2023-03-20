// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

import "bytes-utils/BytesLib.sol";

library BytesLibExt {
    function toUint24(
        bytes memory _bytes,
        uint256 _start
    ) internal pure returns (uint24) {
        require(_bytes.length >= _start + 3, "toUint24_outOfBounds");
        uint24 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x3), _start))
        }

        return tempUint;
    }
}

library Path {
    using BytesLib for bytes;
    using BytesLibExt for bytes;

    /// @dev The length the bytes encoded address
    uint256 private constant ADDR_SIZE = 20;
    /// @dev The length the bytes encoded tickspacing
    uint256 private constant FEE_SIZE = 3;
    /// @dev The offset of a single token address + tick spacing
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + FEE_SIZE;
    /// @dev The offset of a encoded pool key (tokenIn + tick spacing + tokenOut)
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    /// @dev The minumim length of a path that contains 2 or more pools
    uint256 private constant MULTIPLE_POOLS_MIN_LENGTH =
        POP_OFFSET + NEXT_OFFSET;

    /// @dev check if there are multiple pools in a path
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }

    /// @dev to count the number of pools in a path, we subtract the size of an address (first or last token in a path) and divide the remaining part
    function numPools(bytes memory path) internal pure returns (uint256) {
        return (path.length - ADDR_SIZE) / NEXT_OFFSET;
    }

    function getFirstPool(
        bytes memory path
    ) internal pure returns (bytes memory) {
        return path.slice(0, POP_OFFSET);
    }

    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }

    function decodeFirstPool(
        bytes memory path
    )
        internal
        pure
        returns (address tokenIn, address tokenOut, uint24 tickSpacing)
    {
        tokenIn = path.toAddress(0);
        tickSpacing = path.toUint24(ADDR_SIZE);
        tokenOut = path.toAddress(NEXT_OFFSET);
    }
}
