// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/console.sol";
import "forge-std/Script.sol";

import "../src/interfaces/IUniswapV3Manager.sol";
import "../src/lib/FixedPoint96.sol";
import "../src/lib/Math.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Manager.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Quoter.sol";
import "../test/ERC20Mintable.sol";
import "../test/TestUtils.sol";

contract DeployDevelopment is Script, TestUtils {
    struct TokenBalances {
        uint256 uni;
        uint256 usdc;
        uint256 usdt;
        uint256 wbtc;
        uint256 weth;
    }

    TokenBalances balances =
        TokenBalances({
            uni: 200 ether,
            usdc: 2_000_000 ether,
            usdt: 2_000_000 ether,
            wbtc: 20 ether,
            weth: 100 ether
        });

    function run() public {
        // Deploying start
        vm.startBroadcast();

        ERC20Mintable weth = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable usdc = new ERC20Mintable("USD Coin", "USDC", 18);
        ERC20Mintable uni = new ERC20Mintable("Uniswap Coin", "UNI", 18);
        ERC20Mintable wbtc = new ERC20Mintable("Wrapped Bitcoin", "WBTC", 18);
        ERC20Mintable usdt = new ERC20Mintable("USD Token", "USDT", 18);

        // UniswapV3Factory factory = new UniswapV3Factory();
        // UniswapV3Manager manager = new UniswapV3Manager(address(factory));
        // UniswapV3Pool wethUsdc = deployPool()
    }
}
