pragma circom 2.0.3;

include "../snark-jwt-verify/circuits/sha256.circom";
include "../snark-jwt-verify/circomlib/circuits/mux1.circom";

// Copy over 1 block of sha256 input
// Sets bit to 1 at L_pos
template CopyOverBlock(ToCopyBits) {
    signal input L_pos;
    signal input in[ToCopyBits];
    signal output out[ToCopyBits];

    component ie[ToCopyBits];
    component mux[ToCopyBits];
    for (var i = 0; i < ToCopyBits; i++) {
        ie[i] = IsEqual();
        ie[i].in[0] <== i;
        ie[i].in[1] <== L_pos;

        mux[i] = Mux1();
        mux[i].c[0] <== in[i];
        mux[i].c[1] <== 1;
        mux[i].s <== ie[i].out;

        out[i] <== mux[i].out;
    }
}

template Sha256InputBlock(BlockNumber, BlockCount) {
    var BLOCK_LEN = 512;
    var L_BITS = 64;

    var PreLBlockLen = BLOCK_LEN - L_BITS;

    signal input in[BLOCK_LEN];
    signal input len;
    signal output out[BLOCK_LEN];

    var offset = BlockNumber * BLOCK_LEN;

    component cob = CopyOverBlock(BLOCK_LEN);
    component n2b;
    cob.L_pos <== len - offset;
    
    if (BlockNumber < BlockCount - 1) {
        // copy over block number BlockNumber
        for (var i = 0; i < BLOCK_LEN; i++) { cob.in[i] <== in[i]; }
        for (var i = 0; i < BLOCK_LEN; i++) { out[i] <== cob.out[i]; }
    }
    else {
        // copy over pre-L block (last block before L)
        // this block is clipped because 64 bits are reserved for L
        for (var i = 0; i < PreLBlockLen; i++) { cob.in[i] <== in[i]; }
        for (var i = PreLBlockLen; i < BLOCK_LEN; i++) { cob.in[i] <== 0; }

        for (var i = 0; i < PreLBlockLen; i++) { out[i] <== cob.out[i]; }
        // add L
        n2b = Num2Bits(L_BITS);
        n2b.in <== len;
        for (var i = PreLBlockLen; i < BLOCK_LEN; i++) { out[i] <== n2b.out[BLOCK_LEN - 1 - i]; }
    }
}

// Prepare sha256 input for Sha256_unsafe as if it had BlockCount blocks
// This template effectively implements https://datatracker.ietf.org/doc/html/rfc4634#section-4.1 as a circuit
template Sha256Input(BlockCount) {

    // constants
    var BLOCK_LEN = 512;
    var L_BITS = 64;

    // variables
    var PreLBlockLen = BLOCK_LEN - L_BITS;

    // signals
    signal input in[BLOCK_LEN * BlockCount];
    signal input len;
    signal output out[BLOCK_LEN * BlockCount];

    // copy over blocks
    component inputBlock[BlockCount];
    for(var j = 0; j < BlockCount; j++) {
        var offset = j * BLOCK_LEN;

        inputBlock[j] = Sha256InputBlock(j, BlockCount);
        inputBlock[j].len <== len;
        for (var i = 0; i < BLOCK_LEN; i++) { inputBlock[j].in[i] <== in[offset + i]; }
        for (var i = 0; i < BLOCK_LEN; i++) { out[j * BLOCK_LEN + i] <== inputBlock[j].out[i]; }
    }

}