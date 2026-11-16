`timescale 1ns/1ps
// Harvard-style memory system.
//
// Instruction path : PC -> instruction memory -> instruction/valid
// Data path        : data address -> controller -> data memory -> read data
//
// The two memories and their address paths are independent, so an instruction
// fetch and a data read can happen in the same clock cycle.
module harvard_memory_system (
    input  wire        clk,
    input  wire        reset,

    // Instruction fetch path
    output wire [31:0] pc_out,
    output wire [31:0] instruction_out,
    output wire        instruction_valid,

    // Data path
    input  wire [31:0] data_address,
    input  wire        data_read_req,
    input  wire        data_write_req,
    input  wire [31:0] data_write_data,
    output wire [31:0] data_read_data,
    output wire        data_read_valid,
    output wire        data_write_enable,
    output wire        access_error
);

    wire        data_address_valid;

    instruction_fetch fetch_unit (
        .clk         (clk),
        .reset       (reset),
        .pc          (pc_out),
        .instruction (instruction_out),
        .valid       (instruction_valid)
    );

    memory_controller controller (
        .read_request  (data_read_req),
        .write_request (data_write_req),
        .address_valid (data_address_valid),
        .read_enable   (data_read_valid),
        .write_enable  (data_write_enable),
        .access_error  (access_error)
    );

    data_memory dmem (
        .clk            (clk),
        .address        (data_address),
        .read_enable    (data_read_valid),
        .write_enable   (data_write_enable),
        .write_data     (data_write_data),
        .read_data      (data_read_data),
        .valid          (data_address_valid),
        .write_accepted ()
    );

endmodule
