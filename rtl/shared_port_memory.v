`timescale 1ns/1ps
// Single-port shared memory baseline (simplified Von Neumann-style memory).
//
// One 32 x 32-bit array holds both instructions and data:
//   word 0..15  <- instruction byte addresses 0x00..0x3C
//   word 16..31 <- data byte addresses 0x40..0x7C
//
// There is only one physical access port, so at most one request is served per
// clock cycle.  Arbitration policy:
//   1. A new instruction request is served first.
//   2. If data is requested in the same cycle, it is captured in the pending
//      register (the request is not lost).
//   3. While a data request is pending, it is promoted and served next; new
//      instruction requests wait.  This prevents starvation.
//
// Handshake: assert a request with a stable address until its done pulse is
// observed, then deassert it.  Read data is registered and is valid in the
// cycle in which done is high. That requester cannot be serviced again
// during its done cycle; deassert req by the following rising edge. Invalid
// addresses are not acknowledged; callers must validate or time out.
module shared_port_memory (
    input  wire        clk,
    input  wire        reset,

    // Instruction request port
    input  wire        instr_req,
    input  wire [31:0] instr_addr,
    output reg  [31:0] instr_rdata,
    output reg         instr_done,

    // Data request port
    input  wire        data_req,
    input  wire [31:0] data_addr,
    input  wire        data_write,
    input  wire [31:0] data_wdata,
    output reg  [31:0] data_rdata,
    output reg         data_done,

    // Observable arbitration status
    output wire        service_instr,
    output wire        service_data,
    output wire        pending_data
);

    reg [31:0] mem [0:31];

    // Pending data request captured when instruction priority wins.
    reg        pending_valid;
    reg [31:0] pending_addr;
    reg        pending_write;
    reg [31:0] pending_wdata;

    // Address decoding
    wire instr_addr_aligned = (instr_addr[1:0] == 2'b00);
    wire instr_addr_in_range = (instr_addr[31:6] == 26'd0);
    wire instr_addr_valid = instr_addr_aligned && instr_addr_in_range;

    wire data_addr_aligned = (data_addr[1:0] == 2'b00);
    wire data_addr_in_range = (data_addr[31:7] == 25'd0) && (data_addr[6] == 1'b1);
    wire data_addr_valid = data_addr_aligned && data_addr_in_range;

    wire [3:0] instr_word = instr_addr[5:2];

    // Selected pending or direct data request
    wire [31:0] sel_data_addr  = pending_valid ? pending_addr  : data_addr;
    wire        sel_data_write = pending_valid ? pending_write : data_write;
    wire [31:0] sel_data_wdata = pending_valid ? pending_wdata : data_wdata;
    wire [4:0]  sel_data_word  = {1'b1, sel_data_addr[5:2]};

    // Mux BEFORE the array: exactly one physical RTL read port.
    wire [4:0] read_word = service_instr ? {1'b0, instr_word} : sel_data_word;
    wire [31:0] memory_rdata = mem[read_word];

    // A response cycle is a turnaround cycle for that requester. This also
    // prevents a synchronous requester from replaying the completed operation
    // while it observes done and drops its request on the next edge.
    // Arbitration
    assign service_instr = !reset && instr_req && !instr_done &&
                           instr_addr_valid && !pending_valid;
    assign service_data  = !reset && (pending_valid ||
                           (!service_instr && data_req && !data_done && data_addr_valid));
    assign pending_data  = pending_valid;

    always @(posedge clk) begin
        if (reset) begin
            pending_valid <= 1'b0;
            pending_addr  <= 32'd0;
            pending_write <= 1'b0;
            pending_wdata <= 32'd0;
            instr_rdata   <= 32'd0;
            instr_done    <= 1'b0;
            data_rdata    <= 32'd0;
            data_done     <= 1'b0;
        end else begin
            // Done signals are one-cycle pulses.
            instr_done <= 1'b0;
            data_done  <= 1'b0;

            if (service_instr) begin
                instr_rdata <= memory_rdata;
                instr_done  <= 1'b1;

                // Capture a simultaneous data request so it is served next.
                if (!pending_valid && data_req && !data_done && data_addr_valid) begin
                    pending_valid <= 1'b1;
                    pending_addr  <= data_addr;
                    pending_write <= data_write;
                    pending_wdata <= data_wdata;
                end
            end else if (service_data) begin
                if (sel_data_write) begin
                    mem[sel_data_word] <= sel_data_wdata;
                    data_rdata <= sel_data_wdata;
                end else begin
                    data_rdata <= memory_rdata;
                end
                data_done     <= 1'b1;
                pending_valid <= 1'b0;
            end
        end
    end

    initial begin
        // Instruction words (same patterns as the Harvard instruction memory)
        mem[0]  = 32'h00000013;
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

        // Data words: byte addresses 0x40..0x7C
        mem[16] = 32'h00000011;
        mem[17] = 32'h00000022;
        mem[18] = 32'h00000033;
        mem[19] = 32'h00000044;
        mem[20] = 32'h00000055;
        mem[21] = 32'h00000066;
        mem[22] = 32'h00000077;
        mem[23] = 32'h00000088;
        mem[24] = 32'h00000099;
        mem[25] = 32'h000000AA;
        mem[26] = 32'h000000BB;
        mem[27] = 32'h000000CC;
        mem[28] = 32'h000000DD;
        mem[29] = 32'h000000EE;
        mem[30] = 32'h00000123;
        mem[31] = 32'h00000456;
    end

endmodule
