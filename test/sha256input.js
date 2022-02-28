const chai = require("chai");
const path = require("path");
const wasm_tester = require("circom_tester").wasm;
const assert = chai.assert;

const {bufferToBitArray, bitArrayToBuffer, arrayChunk, padMessage} = require("./helpers/utils");

function genSha256Inputs(input, nCount, nWidth = 512, inParam = "in") {
    var segments = arrayChunk(padMessage(bufferToBitArray(Buffer.from(input))), nWidth);
    const tBlock = segments.length / (512 / nWidth);
    
    if(segments.length < nCount) {
        segments = segments.concat(Array(nCount-segments.length).fill(Array(nWidth).fill(0)));
    }
    
    if(segments.length > nCount) {
        throw new Error('Padded message exceeds maximum blocks supported by circuit');
    }
    
    return { segments, "tBlock": tBlock }; 
}

function msgToBits(msg) {
    let inn = bufferToBitArray(Buffer.from(msg))
    const blocks = Math.floor((inn.length + 64) / 512) + 1
    const overall_len = blocks * 512
    const add_bits = overall_len - inn.length
    inn = inn.concat(Array(add_bits).fill(0));
    return inn
}

describe("Sha256", function () {
    this.timeout(100000);

    it ("Should generate input for 0-55 len (1 block)", async () => {
        const p = path.join(__dirname, "../", "circuits", "sha256InputBlock1_test.circom")
        const cir = await wasm_tester(p);

        for(let i=0; i<56; i++) {

            const message = Array(i).fill("a").join("")
            const len = message.length * 8;
            console.log("message", message, len)

            const inn = msgToBits(message)

            const witness = await cir.calculateWitness({ "in": inn, len, tBlock: 1 }, true);

            const arrOut = witness.slice(1, 1 + 512);
            const actual = bitArrayToBuffer(arrOut).toString("hex");

            const expected = bitArrayToBuffer(genSha256Inputs(message, 1).segments[0]).toString('hex')

            assert.equal(actual, expected)
        }
    });


    it ("Should generate input for 56-119 len (2 blocks)", async () => {
        const p = path.join(__dirname, "../", "circuits", "sha256InputBlock2_test.circom")
        const cir = await wasm_tester(p);

        for(let i=56; i<120; i++) {
            const message = Array(i).fill("a").join("")
            const len = message.length * 8;
            const inn = msgToBits(message)
            console.log("message", message, len)
            
            const witness = await cir.calculateWitness({ "in": inn, len, tBlock: 2 }, true);

            const arrOut = witness.slice(1, 1 + (2*512));
            const actual = bitArrayToBuffer(arrOut).toString("hex");
            
            const segments = genSha256Inputs(message, 2).segments
            const expected = bitArrayToBuffer(segments[0].concat(segments[1])).toString('hex')
            
            assert.equal(actual, expected)
        }
    });

    it ("Should generate input for 120-183 len (3 blocks)", async () => {
        const p = path.join(__dirname, "../", "circuits", "sha256InputBlock3_test.circom")
        const cir = await wasm_tester(p);

        for(let i=120; i<183; i++) {
            const message = Array(i).fill("a").join("")
            const len = message.length * 8;
            const inn = msgToBits(message)
            console.log("message", message, len)
            
            const witness = await cir.calculateWitness({ "in": inn, len, tBlock: 3 }, true);

            const arrOut = witness.slice(1, (3*512));
            const actual = bitArrayToBuffer(arrOut).toString("hex");

            const segments = genSha256Inputs(message, 3).segments
            const expected = bitArrayToBuffer(segments[0].concat(segments[1]).concat(segments[2])).toString('hex')

            assert.equal(actual, expected)
        }
    });
});