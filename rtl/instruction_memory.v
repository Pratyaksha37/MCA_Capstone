`timescale 1ns/1ps
// 16 x 32-bit instruction memory with a combinational read port.
// Contents are initialized for simulation and FPGA power-up.  This is a
// simple read-only demonstration memory, not a complete instruction cache.
module instruction_memory #(parameter DEMO_PROGRAM = 0) (
    input  wire [31:0] address,
    output wire [31:0] instruction,
    output wire        valid
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

    // Illegal or unaligned addresses return a defined value.
    assign instruction = valid ? mem[word_index] : 32'h00000000;

    initial begin
        mem[0]  = 32'h00000013;  // NOP-like pattern
        mem[1]  = 32'h00100093;
        mem[2]  = 32'h00200113;
        mem[3]  = 32'h00300193;
        mem[4]  = 32'h00400213;
        mem[5]  = 32'h00500293;
        mem[6]  = 32'h00600313;
        mem[7]  = 32'h00700393;
        mem[8]  = 32'h00800413;
        mem[9]  = 32'h00900493;
        mem[10] = 32'h00A00513;
        mem[11] = 32'h00B00593;
        mem[12] = 32'h00C00613;
        mem[13] = 32'h00D00693;
        mem[14] = 32'h00E00713;
        mem[15] = 32'h00F00793;
        if (DEMO_PROGRAM) begin
            // Small RV32I subset demo (no branches); EBREAK stops the controller.
            mem[0] = 32'h00500093; // addi x1, x0, 5
            mem[1] = 32'h00102023; // sw   x1, 0(x0)
            mem[2] = 32'h00002103; // lw   x2, 0(x0)
            mem[3] = 32'hfff10113; // addi x2, x2, -1
            mem[4] = 32'h02202e23; // sw   x2, 60(x0)
            mem[5] = 32'h03c02183; // lw   x3, 60(x0)
            mem[6] = 32'h00100073; // ebreak
        end
    end

endmodule
