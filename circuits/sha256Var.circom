pragma circom 2.0.3;

include "./Sha256Input.circom";
include "../snark-jwt-verify/circomlib/circuits/mux1.circom";
include "../snark-jwt-verify/circomlib/circuits/mux2.circom";
include "../snark-jwt-verify/circomlib/circuits/mux3.circom";
include "../snark-jwt-verify/circomlib/circuits/mux4.circom";

// Calculate power of x ^ y
function pow(x, y) {
    if (y == 0) {
        return 1;
    } else {
        return x * pow(x, y - 1);
    }
}

// Caclulate sha256 of input of any length within (64 * (2 ^ BlockSpace)) characters
// Takes in array of bits and length of the string in bits
// If any of the bits after len are not 0, the result is undefined behavior
template Sha256Var(BlockSpace) {

    // constants
    var BLOCK_LEN = 512;
    var SHA256_LEN = 256;

    // variables
    var MaxBlockCount = pow(2, BlockSpace);
    var MaxLen = BLOCK_LEN * MaxBlockCount;
    var LenMaxBits = 9 + BlockSpace; // can hold values from 2 ^ 10 to 2 ^ 13

    // signals
    signal input in[MaxLen];
    signal input len;
    signal output out[SHA256_LEN];


    // calculate number of blocks needed (as bits)
    signal len_plus_64;
    len_plus_64 <== len + 64;
    component n2b = Num2Bits(LenMaxBits);
    n2b.in <== len_plus_64;
    component shr = ShR(LenMaxBits, 9); // len_plus_64 >> 9
    for (var i = 0; i < LenMaxBits; i++) {
        shr.in[i] <== n2b.out[i];
    }

    // calculate number of blocks needed (as integer)
    component b2n = Bits2Num(BlockSpace);
    for (var k = 0; k < BlockSpace; k++) { b2n.in[k] <== shr.out[k]; }

    // prepare input based on length and number of blocks 
    component input_blocks = Sha256Input(MaxBlockCount);
    input_blocks.len <== len;
    input_blocks.tBlock <== b2n.out + 1;
    for (var j = 0; j < MaxBlockCount; j++) {
        for (var i = 0; i < BLOCK_LEN; i++) {
            input_blocks.in[j * BLOCK_LEN + i] <== in[j * BLOCK_LEN + i];
        }
    }

    // put the selected input into sha256
    component sha256_unsafe = Sha256_unsafe(MaxBlockCount);
    sha256_unsafe.tBlock <== b2n.out + 1;
    for (var j = 0; j < MaxBlockCount; j++) {
        for (var i = 0; i < BLOCK_LEN; i++) {
            sha256_unsafe.in[j][i] <== input_blocks.out[j * BLOCK_LEN + i];
        }
    }

    // copy the output
    for (var i = 0; i < SHA256_LEN; i++) {
        out[i] <== sha256_unsafe.out[i];
    }
}

