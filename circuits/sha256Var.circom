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

// Switch between MultiMux[1-4] dynamically during compile time
// MuxSpace is only supported to be between 1 and 4
template MultiMultiMux(MuxSpace, n) {
    var MaxVariants = pow(2, MuxSpace);

    signal input in[MaxVariants][n];
    signal input selector[MuxSpace];
    signal output out[n];

    component mux1 = MultiMux1(n);
    component mux2 = MultiMux2(n);
    component mux3 = MultiMux3(n);
    component mux4 = MultiMux4(n);

    if (MuxSpace == 1) {
        for (var j = 0; j < MaxVariants; j++) {
            for (var i = 0; i < n; i++) { mux1.c[i][j] <== in[j][i]; }
        }
        mux1.s <== selector[0];
        for (var i = 0; i < n; i++) { out[i] <== mux1.out[i]; }
    } 
    else if (MuxSpace == 2) {
        for (var j = 0; j < MaxVariants; j++) {
            for (var i = 0; i < n; i++) { mux2.c[i][j] <== in[j][i]; }
        }
        for (var k = 0; k < MuxSpace; k++) { mux2.s[k] <== selector[k]; }
        for (var i = 0; i < n; i++) { out[i] <== mux2.out[i]; }
    }
    else if (MuxSpace == 3) {
        for (var j = 0; j < MaxVariants; j++) {
            for (var i = 0; i < n; i++) { mux3.c[i][j] <== in[j][i]; }
        }
        for (var k = 0; k < MuxSpace; k++) { mux3.s[k] <== selector[k]; }
        for (var i = 0; i < n; i++) { out[i] <== mux3.out[i]; }
    }
    else if (MuxSpace == 4) {
        for (var j = 0; j < MaxVariants; j++) {
            for (var i = 0; i < n; i++) { mux4.c[i][j] <== in[j][i]; }
        }
        for (var k = 0; k < MuxSpace; k++) { mux4.s[k] <== selector[k]; }
        for (var i = 0; i < n; i++) { out[i] <== mux4.out[i]; }
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


    // prepare sha256 inputs as if it were p + 1 blocks
    // component input_j_block[MaxBlockCount];
    // for (var p = 0; p < MaxBlockCount; p++) {
    //     var blocks = p + 1;
    //     input_j_block[p] = Sha256Input(blocks);
    //     input_j_block[p].len <== len;
    //     for (var j = 0; j < blocks; j++) {
    //         for (var i = 0; i < BLOCK_LEN; i++) {
    //             input_j_block[p].in[j * BLOCK_LEN + i] <== in[j * BLOCK_LEN + i];
    //         }
    //     }
    // }

    // calculate number of blocks needed (as bits)
    signal len_plus_64;
    len_plus_64 <== len + 64;
    component n2b = Num2Bits(LenMaxBits);
    n2b.in <== len_plus_64;
    component shr = ShR(LenMaxBits, 9); // len_plus_64 >> 9
    for (var i = 0; i < LenMaxBits; i++) {
        shr.in[i] <== n2b.out[i];
    }

    // switch between sha256 inputs based on number of blocks (len_plus_64 >> 9)
    // component mmm = MultiMultiMux(BlockSpace, MaxLen);
    // for (var p = 0; p < MaxBlockCount; p++) {
    //     var blocks = p + 1;
    //     // copy over blocks of the input into the multiplexer
    //     for (var j = 0; j < blocks; j++) {
    //         for (var i = 0; i < BLOCK_LEN; i++) {
    //             mmm.in[p][j * BLOCK_LEN + i] <== input_j_block[p].out[j * BLOCK_LEN + i];
    //         }
    //     }
    //     // pad with zeros for the inputs which have less than max blocks
    //     for (var j = blocks; j < MaxBlockCount; j++) {
    //         for (var i = 0; i < BLOCK_LEN; i++) {
    //             mmm.in[p][j * BLOCK_LEN + i] <== 0;
    //         }
    //     }
    // }
    // for (var k = 0; k < BlockSpace; k++) { mmm.selector[k] <== shr.out[k]; }

    // calculate number of blocks needed (as integer)
    component b2n = Bits2Num(BlockSpace);
    for (var k = 0; k < BlockSpace; k++) { b2n.in[k] <== shr.out[k]; }

    component input_j_block = Sha256Input(MaxBlockCount);
    input_j_block.len <== len;
    input_j_block.tBlock <== b2n.out + 1;
    for (var j = 0; j < MaxBlockCount; j++) {
        for (var i = 0; i < BLOCK_LEN; i++) {
            input_j_block.in[j * BLOCK_LEN + i] <== in[j * BLOCK_LEN + i];
        }
    }


    // put the selected input into sha256
    component sha256_unsafe = Sha256_unsafe(MaxBlockCount);
    sha256_unsafe.tBlock <== b2n.out + 1;
    for (var j = 0; j < MaxBlockCount; j++) {
        for (var i = 0; i < BLOCK_LEN; i++) {
            sha256_unsafe.in[j][i] <== input_j_block.out[j * BLOCK_LEN + i];//mmm.out[j * BLOCK_LEN + i];
        }
    }

    // copy the output
    for (var i = 0; i < SHA256_LEN; i++) {
        out[i] <== sha256_unsafe.out[i];
    }
}

