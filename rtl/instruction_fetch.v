`timescale 1ns/1ps
// Instruction fetch path: program counter plus instruction memory.
// The instruction is available combinationally for the current PC value.
module instruction_fetch (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc,
    output wire [31:0] instruction,
    output wire        valid
);

    wire [31:0] pc_value;

    program_counter pc_unit (
        .clk   (clk),
        .reset (reset),
        .pc    (pc_value)
    );

    instruction_memory imem (
        .address     (pc_value),
        .instruction (instruction),
        .valid       (valid)
    );

    assign pc = pc_value;

endmodule
