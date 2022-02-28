const chai = require("chai");
const path = require("path");
const crypto = require("crypto");
const wasm_tester = require("circom_tester").wasm;
const assert = chai.assert;

const {bufferToBitArray, bitArrayToBuffer} = require("./helpers/utils");

function msgToBits(msg, blocks) {
    let inn = bufferToBitArray(Buffer.from(msg))
    const overall_len = blocks * 512
    const add_bits = overall_len - inn.length
    inn = inn.concat(Array(add_bits).fill(0));
    return inn
}

async function testBlockSpace(block_space) {
    const blocks = Math.pow(2, block_space);
    const max_len = (blocks * 512 - 64) / 8;
    console.log('block_space', block_space, 'blocks', blocks, 'max_len', max_len);

    const p = path.join(__dirname, `../circuits/Sha256VarSpace${block_space}_test.circom`)
    const cir = await wasm_tester(p);

    for(let i = 0; i < max_len; i++) {
        const message = Array(i).fill("a").join("")
        const len = message.length * 8;
        const inn = msgToBits(message, blocks)
        console.log("message", message, len, len / 8)

        const witness = await cir.calculateWitness({ "in": inn, len }, true);

        const arrOut = witness.slice(1, 257);
        const actualHash = bitArrayToBuffer(arrOut).toString("hex");
        const expectedHash = crypto.createHash('sha256').update(message).digest('hex')
        assert.equal(actualHash, expectedHash)
    }
}

describe("Sha256", function () {
    this.timeout(1000000000);

    it ("Should generate hash for 1 block space", async () => {
        await testBlockSpace(1);
    });

    it ("Should generate hash for 2 block space", async () => {
        await testBlockSpace(2);
    });

    it ("Should generate hash for 3 block space", async () => {
        await testBlockSpace(3);
    });

    it ("Should generate hash for 4 block space", async () => {
        await testBlockSpace(4);
    });


});