# Sha256Var.circom
Variable length sha256 hash function in [Circom](https://docs.circom.io/).

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
We take the avaialble block space and prepare `2^BlockSpace` blocks. We put the data into the blocks. Each block is prepared using the `Sha256InputBlock` component which expects the block to either be the last block or not. If it is the last block, `L` is added in the last 64 bits. If it's not, block is copied over normally. The `1` bit is also set at the end of the input length.

## Limitations
The bigger the block space, the bigger the circuit. While 1 and 2 block spaces are ok, the 3 block space is slow and the 4 is slower.

## Performance
Measured on a Mac

|              | compile time (s) | run time (s) | constraints (lines in .sym file) |
|--------------|------------------|--------------|----------------------------------|
| BlockSpace=1 |            6.221 |       27.303 |                           435332 |
| BlockSpace=2 |           12.055 |        96.13 |                           869606 |
| BlockSpace=3 |           24.241 |       350.22 |                          1738150 |
| BlockSpace=4 |           51.843 |     1356.917 |                          3475234 |

## Tests
- Run `make test`
