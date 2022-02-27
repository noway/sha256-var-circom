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

template Sha256InputBlock(BlockNumber) {
    var BLOCK_LEN = 512;
    var L_BITS = 64;

    var PreLBlockLen = BLOCK_LEN - L_BITS;

    signal input in[BLOCK_LEN];
    signal input len;
    signal input isNotLast;
    signal output out[BLOCK_LEN];

    signal offset;

    offset <== BlockNumber * BLOCK_LEN;

    component cob = CopyOverBlock(BLOCK_LEN);
    cob.L_pos <== len - offset;
    component n2b = Num2Bits(L_BITS);
    n2b.in <== len;

    // copy over the block up to pre-L length
    for (var i = 0; i < BLOCK_LEN; i++) { cob.in[i] <== in[i]; }
    for (var i = 0; i < PreLBlockLen; i++) { out[i] <== cob.out[i]; }

    component mux[BLOCK_LEN - PreLBlockLen];
    for (var i = PreLBlockLen; i < BLOCK_LEN; i++) {
        var j = i - PreLBlockLen;
        mux[j] = Mux1();
        mux[j].c[0] <== n2b.out[BLOCK_LEN - 1 - i];
        mux[j].c[1] <== cob.out[i];
        mux[j].s <== isNotLast;
        out[i] <== mux[j].out;
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

        inputBlock[j] = Sha256InputBlock(j);
        inputBlock[j].len <== len;
        inputBlock[j].isNotLast <== j < BlockCount - 1;
        for (var i = 0; i < BLOCK_LEN; i++) { inputBlock[j].in[i] <== in[offset + i]; }
        for (var i = 0; i < BLOCK_LEN; i++) { out[j * BLOCK_LEN + i] <== inputBlock[j].out[i]; }
    }

}