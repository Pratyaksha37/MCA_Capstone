`timescale 1ns/1ps

// Directed test for the single-port shared memory: instruction-only and
// data-only requests, simultaneous requests, instruction priority, pending
// data retention, anti-starvation promotion, and data write/read-back.
module tb_shared_port_memory;

    reg        clk;
    reg        reset;
    reg        instr_req;
    reg [31:0] instr_addr;
    wire [31:0] instr_rdata;
    wire        instr_done;
    reg        data_req;
    reg [31:0] data_addr;
    reg        data_write;
    reg [31:0] data_wdata;
    wire [31:0] data_rdata;
    wire        data_done;
    wire        service_instr;
    wire        service_data;
    wire        pending_data;
    integer     checks;

    shared_port_memory dut (
        .clk           (clk),
        .reset         (reset),
        .instr_req     (instr_req),
        .instr_addr    (instr_addr),
        .instr_rdata   (instr_rdata),
        .instr_done    (instr_done),
        .data_req      (data_req),
        .data_addr     (data_addr),
        .data_write    (data_write),
        .data_wdata    (data_wdata),
        .data_rdata    (data_rdata),
        .data_done     (data_done),
        .service_instr (service_instr),
        .service_data  (service_data),
        .pending_data  (pending_data)
    );

    always #5 clk = ~clk;

    task check32;
        input [8*48-1:0] label;
        input [31:0]     got;
        input [31:0]     exp;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                $display("FAIL [%0s]: got %08h, expected %08h", label, got, exp);
                $fatal(1, "shared memory test failed");
            end
        end
    endtask

    task check1;
        input [8*48-1:0] label;
        input            got;
        input            exp;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                $display("FAIL [%0s]: got %b, expected %b", label, got, exp);
                $fatal(1, "shared memory test failed");
            end
        end
    endtask

    task instr_access;
        input [31:0] addr;
        input [31:0] exp;
        begin
            @(negedge clk);
            instr_addr = addr;
            instr_req = 1'b1;
            #1;
            check1("instruction service selected", service_instr, 1'b1);
            @(negedge clk);
            check1("instruction done", instr_done, 1'b1);
            check32("instruction response", instr_rdata, exp);
            instr_req = 1'b0;
            @(negedge clk);
            check1("instruction done clears", instr_done, 1'b0);
        end
    endtask

    task data_access;
        input [31:0] addr;
        input [31:0] exp;
        begin
            @(negedge clk);
            data_addr = addr;
            data_write = 1'b0;
            data_req = 1'b1;
            #1;
            check1("data service selected", service_data, 1'b1);
            @(negedge clk);
            check1("data done", data_done, 1'b1);
            check32("data response", data_rdata, exp);
            data_req = 1'b0;
            @(negedge clk);
            check1("data done clears", data_done, 1'b0);
        end
    endtask

    task data_write_word;
        input [31:0] addr;
        input [31:0] value;
        begin
            @(negedge clk);
            data_addr = addr;
            data_wdata = value;
            data_write = 1'b1;
            data_req = 1'b1;
            #1;
            check1("write service selected", service_data, 1'b1);
            @(negedge clk);
            check1("write done", data_done, 1'b1);
            check32("write response echoes data", data_rdata, value);
            data_req = 1'b0;
            data_write = 1'b0;
            @(negedge clk);
            check1("write done clears", data_done, 1'b0);
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/tb_shared_port_memory.vcd");
        $dumpvars(0, tb_shared_port_memory);

        clk = 1'b0;
        reset = 1'b1;
        instr_req = 1'b0;
        instr_addr = 32'd0;
        data_req = 1'b0;
        data_addr = 32'd0;
        data_write = 1'b0;
        data_wdata = 32'd0;
        checks = 0;

        #12;
        @(negedge clk);
        reset = 1'b0;

        // Instruction-only accesses, including the last instruction word.
        instr_access(32'd8, 32'h00200113);
        instr_access(32'd60, 32'h00F00793);

        // Data-only accesses, including the last data word.
        data_access(32'h00000044, 32'h00000022);
        data_access(32'h0000007C, 32'h00000456);

        // Simultaneous requests: instruction is served first, data is retained.
        @(negedge clk);
        instr_addr = 32'd0;
        instr_req = 1'b1;
        data_addr = 32'h00000040;
        data_req = 1'b1;
        #1;
        check1("priority selects instruction", service_instr, 1'b1);
        check1("priority blocks data service", service_data, 1'b0);
        check1("no pending data before edge", pending_data, 1'b0);
        $display("SHARED_ARBITRATION: service_instr=%b service_data=%b pending_data=%b",
                 service_instr, service_data, pending_data);

        @(negedge clk);
        check1("instruction completed first", instr_done, 1'b1);
        check32("instruction first response", instr_rdata, 32'h00000013);
        check1("data not completed in first cycle", data_done, 1'b0);
        check1("data request retained", pending_data, 1'b1);
        $display("SHARED_AFTER_CYCLE1: service_instr=%b service_data=%b instr_done=%b data_done=%b pending_data=%b instr=%08h",
                 service_instr, service_data, instr_done, data_done, pending_data, instr_rdata);

        // Keep instruction request asserted: pending data must still be served.
        @(negedge clk);
        check1("pending data completed", data_done, 1'b1);
        check32("pending data response", data_rdata, 32'h00000011);
        check1("instruction done deasserted", instr_done, 1'b0);
        check1("pending flag cleared", pending_data, 1'b0);
        $display("SHARED_AFTER_CYCLE2: service_instr=%b service_data=%b instr_done=%b data_done=%b pending_data=%b data=%08h",
                 service_instr, service_data, instr_done, data_done, pending_data, data_rdata);
        instr_req = 1'b0;
        data_req = 1'b0;

        @(negedge clk);
        check1("data done pulse ends", data_done, 1'b0);

        // Runtime data write and read-back through the shared port.
        data_write_word(32'h00000048, 32'hDEADBEEF);
        data_access(32'h00000048, 32'hDEADBEEF);

        // The data write must not corrupt the instruction region.
        instr_access(32'd8, 32'h00200113);

        $display("TB_SHARED_PORT_MEMORY: PASS (%0d checks)", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "shared memory test timed out");
    end

endmodule
