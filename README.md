# UniswapV3

!["uniswap"](https://miro.medium.com/v2/resize:fit:4800/format:webp/1*6vk9znWaXEeNdTdsZxzWOA.jpeg)

## This project implements the core of Uniswap, its hardest and most important mechanisms:

- _UniswapV3Pool_ - the core pool contract that implements liquidity management and swapping. This contract is very close to the original one, however, some implementation details are different and something is missed for simplicity. For example, our implementation will only handle “exact input” swaps, that is swaps with known input amounts. The original implementation also supports swaps with known output amounts (i.e. when you want to buy a certain amount of tokens).
- _UniswapV3Factory_ – the registry contract that deploys new pools and keeps a record of all deployed pools. This one is mostly identical to the original one besides the ability to change owner and fees.
- _UniswapV3Manager_ – a periphery contract that makes it easier to interact with the pool contract. This is a very simplified implementation of SwapRouter. Again, as you can see, I don’t distinguish “exact input” and “exact output” swaps and implement only the former ones.
- _UniswapV3Quoter_ is a cool contract that allows calculating swap prices on-chain. This is a minimal copy of both Quoter and QuoterV2. Again, only “exact input” swaps are supported.
- _UniswapV3NFTManager_ allows turning liquidity positions into NFTs. This is a simplified implementation of NonfungiblePositionManager.
