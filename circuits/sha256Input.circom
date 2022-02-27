pragma circom 2.0.3;

include "../snark-jwt-verify/circuits/sha256.circom";
include "../snark-jwt-verify/circomlib/circuits/mux1.circom";

// Copy over 1 block of sha256 input
// Sets bit to 1 at L_pos
template CopyOverBlock(ToCopyBits) {
    // signals
    signal input L_pos;
    signal input in[ToCopyBits];
    signal output out[ToCopyBits];

    // copy over the block
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

// Prepare 1 sha256 input block
template Sha256InputBlock(BlockNumber) {
    // constants
    var BLOCK_LEN = 512;
    var L_BITS = 64;

    // variables
    var PreLBlockLen = BLOCK_LEN - L_BITS;

    // signals
    signal input in[BLOCK_LEN];
    signal input len;
    signal input isLast;
    signal output out[BLOCK_LEN];

    // prepare CopyOverBlock
    component cob = CopyOverBlock(BLOCK_LEN);
    cob.L_pos <== len - (BlockNumber * BLOCK_LEN);

    // prepare L
    component n2b = Num2Bits(L_BITS);
    n2b.in <== len;

    // copy over the block up to pre-L length
    for (var i = 0; i < BLOCK_LEN; i++) { cob.in[i] <== in[i]; }
    for (var i = 0; i < PreLBlockLen; i++) { out[i] <== cob.out[i]; }

    // copy over the L or the rest of the block
    component mux[BLOCK_LEN - PreLBlockLen];
    for (var i = PreLBlockLen; i < BLOCK_LEN; i++) {
        var j = i - PreLBlockLen;
        mux[j] = Mux1();
        mux[j].c[1] <== n2b.out[BLOCK_LEN - 1 - i];
        mux[j].c[0] <== cob.out[i];
        mux[j].s <== isLast;
        out[i] <== mux[j].out;
    }
}

// Prepare sha256 input for Sha256_unsafe with tBlock as the current number of blocks
// and MaxBlockCount being the maximum number of blocks
// This template effectively implements https://datatracker.ietf.org/doc/html/rfc4634#section-4.1 as a circuit
template Sha256Input(MaxBlockCount) {

    // constants
    var BLOCK_LEN = 512;
    var L_BITS = 64;

    // variables
    var PreLBlockLen = BLOCK_LEN - L_BITS;

    // signals
    signal input in[BLOCK_LEN * MaxBlockCount];
    signal input len;
    signal input tBlock;
    signal output out[BLOCK_LEN * MaxBlockCount];

    // copy over blocks
    component inputBlock[MaxBlockCount];
    component iz[MaxBlockCount];
    for(var j = 0; j < MaxBlockCount; j++) {
        var offset = j * BLOCK_LEN;

        iz[j] = IsZero();
        iz[j].in <== j - tBlock + 1;
        inputBlock[j] = Sha256InputBlock(j);
        inputBlock[j].len <== len;
        inputBlock[j].isLast <== iz[j].out;
        for (var i = 0; i < BLOCK_LEN; i++) { inputBlock[j].in[i] <== in[offset + i]; }
        for (var i = 0; i < BLOCK_LEN; i++) { out[offset + i] <== inputBlock[j].out[i]; }
    }

}