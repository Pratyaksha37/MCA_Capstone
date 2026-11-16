`timescale 1ns/1ps
// 16 x 32-bit data memory.
//
// Timing model:
//   * read_data is combinational and is valid when read_enable && valid.
//   * A write is accepted on the rising clock edge when write_enable && valid.
//   * A read during a write returns the old word; the new word is stored at
//     the clock edge.
//
// The array contents are initialized at time zero and are NOT cleared by the
// system reset.  This models a small memory array whose stored data persists;
// reset only affects the program counter and arbitration state.
module data_memory (
    input  wire        clk,
    input  wire [31:0] address,
    input  wire        read_enable,
    input  wire        write_enable,
    input  wire [31:0] write_data,
    output wire [31:0] read_data,
    output wire        valid,
    output wire        write_accepted
);

    reg [31:0] mem [0:15];

    wire [3:0] word_index;
    wire       aligned;
    wire       in_range;

    address_decoder decoder (
        .byte_address (address),
        .word_index   (word_index),
        .aligned      (aligned),
        .in_range     (in_range),
        .valid        (valid)
    );

    assign read_data      = (read_enable && valid) ? mem[word_index] : 32'h00000000;
    assign write_accepted = write_enable && valid;

    always @(posedge clk) begin
        if (write_enable && valid)
            mem[word_index] <= write_data;
    end

    initial begin
        mem[0]  = 32'h00000011;
        mem[1]  = 32'h00000022;
        mem[2]  = 32'h00000033;
        mem[3]  = 32'h00000044;
        mem[4]  = 32'h00000055;
        mem[5]  = 32'h00000066;
        mem[6]  = 32'h00000077;
        mem[7]  = 32'h00000088;
        mem[8]  = 32'h00000099;
        mem[9]  = 32'h000000AA;
        mem[10] = 32'h000000BB;
        mem[11] = 32'h000000CC;
        mem[12] = 32'h000000DD;
        mem[13] = 32'h000000EE;
        mem[14] = 32'h00000123;
        mem[15] = 32'h00000456;
    end

endmodule
