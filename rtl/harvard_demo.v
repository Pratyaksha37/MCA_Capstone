`timescale 1ns/1ps
// Executable Harvard example: ADDI, LW, SW, and exact EBREAK only.
// Each instruction retires on one rising edge using independent asynchronous
// instruction/data reads. This is a teaching controller, not a complete CPU.
module harvard_demo (
    input wire clk,
    input wire reset,
    output reg [31:0] pc,
    output wire [31:0] instruction,
    output reg halted,
    output reg fault,
    output reg [31:0] retired,
    output wire [31:0] result,
    output wire data_read,
    output wire data_write
);
    reg [31:0] regs [0:31];
    integer i;
    wire instruction_valid;
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd = instruction[11:7];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};
    wire [31:0] imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    wire is_addi = opcode == 7'h13 && instruction[14:12] == 3'b000;
    wire is_load = opcode == 7'h03 && instruction[14:12] == 3'b010;
    wire is_store = opcode == 7'h23 && instruction[14:12] == 3'b010;
    wire is_halt = instruction == 32'h00100073;
    wire running = !reset && !halted && !fault && instruction_valid;
    wire [31:0] address = regs[rs1] + (is_store ? imm_s : imm_i);
    wire [31:0] read_data;
    wire address_valid, access_error;
    wire read_request = running && is_load;
    wire write_request = running && is_store;
    assign result = regs[3];

    instruction_memory #(.DEMO_PROGRAM(1)) imem (
        .address(pc), .instruction(instruction), .valid(instruction_valid)
    );
    memory_controller control (
        .read_request(read_request), .write_request(write_request),
        .address_valid(address_valid), .read_enable(data_read),
        .write_enable(data_write), .access_error(access_error)
    );
    data_memory dmem (
        .clk(clk), .address(address), .read_enable(data_read),
        .write_enable(data_write), .write_data(regs[rs2]),
        .read_data(read_data), .valid(address_valid), .write_accepted()
    );

    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
            halted <= 0;
            fault <= 0;
            retired <= 0;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 0;
        end else if (!halted && !fault) begin
            if (!instruction_valid || access_error ||
                !(is_addi || is_load || is_store || is_halt)) begin
                fault <= 1;
            end else begin
                retired <= retired + 1;
                if (is_halt) halted <= 1;
                else begin
                    pc <= pc + 4;
                    if (rd != 0 && is_addi) regs[rd] <= regs[rs1] + imm_i;
                    if (rd != 0 && is_load) regs[rd] <= read_data;
                end
            end
        end
    end
endmodule
