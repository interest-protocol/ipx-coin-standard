# IPX Coin Standard

## It wraps `sui::coin::TreasuryCap` and adds capabilities to mint, burn and manage the metadata of coins.

### It adds the following capabilities:

-   `MintCap` to mint the coins
-   `BurnCap` to burn coins
-   `MetadataCap` to manage the metadata of coins

The deployer can opt to not mint a `BurnCap` and instead allow anyone to burn his/her own coins.

## Immutable

[The package is immutable](https://suiscan.xyz/mainnet/tx/6WtXuEpdc4kW5rRotH9VcVTkNGPzK89gcNuS9z1rUeQu)

## Mainnet Code

[Explorer](https://suiscan.xyz/mainnet/object/0xce7bfdc0f92c399bebda987cd123540ddf6d6ff37d78deeea97b69190aac49b1/contracts)

sui client call --package 0x2 --module package --gas-budget 50000000 --function make_immutable --args 0x9f8cca5be0bed7c447b3d1430f3b099cd439e66f72e0601c0a22475782eb4c00
