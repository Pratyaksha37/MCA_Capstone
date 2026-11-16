`timescale 1ns/1ps
// Decodes a byte address for a 16-word (64-byte) word-aligned memory.
//
//   byte address 0x00 -> word 0
//   byte address 0x04 -> word 1
//   ...
//   byte address 0x3C -> word 15
//
// valid is high only for an aligned address inside this range.  Out-of-range
// and unaligned addresses therefore cannot select a memory word silently.
module address_decoder (
    input  wire [31:0] byte_address,
    output wire [3:0]  word_index,
    output wire        aligned,
    output wire        in_range,
    output wire        valid
);

    assign aligned   = (byte_address[1:0] == 2'b00);
    assign in_range  = (byte_address[31:6] == 26'd0);
    assign valid     = aligned && in_range;
    assign word_index = byte_address[5:2];

endmodule
