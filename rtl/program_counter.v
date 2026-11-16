`timescale 1ns/1ps
// 32-bit byte-addressed program counter.
// Synchronous active-high reset forces the PC to zero.
// Otherwise the PC advances by one 32-bit word (4 bytes) every clock edge.
module program_counter (
    input  wire        clk,
    input  wire        reset,
    output reg  [31:0] pc
);

    always @(posedge clk) begin
        if (reset)
            pc <= 32'd0;
        else
            pc <= pc + 32'd4;
    end

endmodule
