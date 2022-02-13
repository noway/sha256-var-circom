# Sha256Var.circom
Variable length sha256 hash function in Circom

## Problem
- [Sha256](https://github.com/iden3/circomlib/tree/master/circuits/sha256) function from [circomlib](https://github.com/iden3/circomlib) requires length of the input to be known at compile time.
- [Sha256](https://github.com/TheFrozenFire/snark-jwt-verify/blob/master/circuits/sha256.circom) function from [TheFrozenFire/snark-jwt-verify](https://github.com/TheFrozenFire/snark-jwt-verify) requires the input to be crafted in a special format by an out-of-circuit function.

## Solution
Building on [TheFrozenFire/snark-jwt-verify](https://github.com/TheFrozenFire/snark-jwt-verify), this circuit implements variable length sha256 hash function in Circom.

## Usage
Given `input` (in bits) of length `input_len` (in bits), the following code returns the hash of `input`:

```circom
var BLOCK_LEN = 512;
var MAX_BLOCKS = 2;
var SHA256_LEN = 256;

// See bellow for explanation
var BlockSpace = 1;

component sha256 = Sha256Var(BlockSpace);

// Set input
sha256.len <== input_len;
for (var i = 0; i < BLOCK_LEN * MAX_BLOCKS; i++) {
    sha256.in[i] <== input[i];
}

// Export the sha256 hash
for (var i = 0; i < SHA256_LEN; i++) {
    hash[i] <== sha256.out[i];
}
```

For more usage, see [test/sha256var.js](test/sha256var.js).

## Block space cheat sheet
- 1 block space = max 2 blocks = max 960 bits = 0-119 characters
- 2 block space = max 4 blocks = max 1984 bits = 0-247 characters
- 3 block space = max 8 blocks = max 4032 bits = 0-503 characters
- 4 block space = max 16 blocks = max 8128 bits = 0-1015 characters

## How it works
The circuit prepares inputs for every possible block count of the input. I.e., if 4 blocks are max, the 1, 2, 3, and 4 block inputs are prepared. Then, the correct block count is determined by using a multiplexer with length as the selector.

## Limitations
The bigger the block space, the bigger the circuit. While 1 and 2 block spaces are ok, the 3 block space is slow and the 4 is slower.

## Tests
- Run `make test`