`timescale 1ns/1ps

// Integration test for the Harvard memory system: PC, instruction fetch,
// independent data reads/writes, address errors, write priority, and a
// simultaneous instruction fetch + data access.
module tb_harvard_memory_system;

    reg        clk;
    reg        reset;
    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire        instruction_valid;
    reg [31:0] data_address;
    reg        data_read_req;
    reg        data_write_req;
    reg [31:0] data_write_data;
    wire [31:0] data_read_data;
    wire        data_read_valid;
    wire        data_write_enable;
    wire        access_error;
    integer     checks;
    integer     i;
    reg [31:0]  pc_snapshot;
    reg [31:0] expected_instr [0:15];

    harvard_memory_system dut (
        .clk               (clk),
        .reset             (reset),
        .pc_out            (pc_out),
        .instruction_out   (instruction_out),
        .instruction_valid (instruction_valid),
        .data_address      (data_address),
        .data_read_req     (data_read_req),
        .data_write_req    (data_write_req),
        .data_write_data   (data_write_data),
        .data_read_data    (data_read_data),
        .data_read_valid   (data_read_valid),
        .data_write_enable (data_write_enable),
        .access_error      (access_error)
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
                $fatal(1, "Harvard integration test failed");
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
                $fatal(1, "Harvard integration test failed");
            end
        end
    endtask

    initial begin
        expected_instr[0]  = 32'h00000013;
        expected_instr[1]  = 32'h00100093;
        expected_instr[2]  = 32'h00200113;
        expected_instr[3]  = 32'h00300193;
        expected_instr[4]  = 32'h00400213;
        expected_instr[5]  = 32'h00500293;
        expected_instr[6]  = 32'h00600313;
        expected_instr[7]  = 32'h00700393;
        expected_instr[8]  = 32'h00800413;
        expected_instr[9]  = 32'h00900493;
        expected_instr[10] = 32'h00A00513;
        expected_instr[11] = 32'h00B00593;
        expected_instr[12] = 32'h00C00613;
        expected_instr[13] = 32'h00D00693;
        expected_instr[14] = 32'h00E00713;
        expected_instr[15] = 32'h00F00793;
    end

    initial begin
        $dumpfile("results/waveforms/tb_harvard_memory_system.vcd");
        $dumpvars(0, tb_harvard_memory_system);

        clk = 1'b0;
        reset = 1'b1;
        data_address = 32'd0;
        data_read_req = 1'b0;
        data_write_req = 1'b0;
        data_write_data = 32'd0;
        checks = 0;

        #12;
        check1("instruction valid after reset", instruction_valid, 1'b1);
        check32("PC after reset", pc_out, 32'd0);
        check32("instruction at PC 0", instruction_out, expected_instr[0]);

        @(negedge clk);
        reset = 1'b0;

        // PC keeps advancing while the data path is idle.
        for (i = 1; i < 5; i = i + 1) begin
            @(negedge clk);
            check32("PC advance", pc_out, i * 4);
            check32("instruction follows PC", instruction_out, expected_instr[pc_out[5:2]]);
        end

        // Data read while the instruction path is fetching.
        @(negedge clk);
        data_address = 32'd4;
        data_read_req = 1'b1;
        #1;
        check1("data read valid", data_read_valid, 1'b1);
        check32("data read value", data_read_data, 32'h00000022);
        check1("no access error", access_error, 1'b0);
        check1("instruction still valid during data read", instruction_valid, 1'b1);
        data_read_req = 1'b0;

        // Data write and read-back.
        @(negedge clk);
        data_address = 32'd8;
        data_write_req = 1'b1;
        data_write_data = 32'hCAFEBABE;
        #1;
        check1("write enable", data_write_enable, 1'b1);
        check1("read suppressed during write", data_read_valid, 1'b0);
        check1("instruction fetch during write", instruction_valid, 1'b1);
        @(posedge clk);
        @(negedge clk);
        data_write_req = 1'b0;

        @(negedge clk);
        data_read_req = 1'b1;
        #1;
        check1("write read-back valid", data_read_valid, 1'b1);
        check32("write read-back value", data_read_data, 32'hCAFEBABE);
        data_read_req = 1'b0;

        // Simultaneous instruction fetch and data access on independent paths.
        @(negedge clk);
        pc_snapshot = pc_out;
        data_address = 32'd0;
        data_read_req = 1'b1;
        #1;
        check1("simultaneous instr valid", instruction_valid, 1'b1);
        check32("simultaneous instruction", instruction_out, expected_instr[pc_out[5:2]]);
        check1("simultaneous data valid", data_read_valid, 1'b1);
        check32("simultaneous data value", data_read_data, 32'h00000011);
        check1("simultaneous no error", access_error, 1'b0);
        // The PC has not advanced, so both accesses belong to this cycle.
        check32("simultaneous PC stable", pc_out, pc_snapshot);
        $display("HARVARD_SIMULTANEOUS: pc=%08h instruction=%08h data=%08h instruction_valid=%b data_read_valid=%b",
                 pc_out, instruction_out, data_read_data, instruction_valid, data_read_valid);
        data_read_req = 1'b0;
        @(posedge clk);
        @(negedge clk);

        // Invalid addresses must be rejected, not silently decoded.
        @(negedge clk);
        data_address = 32'd64;
        data_read_req = 1'b1;
        #1;
        check1("out-of-range access error", access_error, 1'b1);
        check1("out-of-range read invalid", data_read_valid, 1'b0);
        check32("out-of-range read zero", data_read_data, 32'h00000000);

        @(negedge clk);
        data_address = 32'd2;
        #1;
        check1("unaligned access error", access_error, 1'b1);
        check1("unaligned read invalid", data_read_valid, 1'b0);
        data_read_req = 1'b0;

        // Simultaneous read + write: the documented write-priority policy.
        @(negedge clk);
        data_address = 32'd12;
        data_read_req = 1'b1;
        data_write_req = 1'b1;
        data_write_data = 32'hA5A5A5A5;
        #1;
        check1("priority write enable", data_write_enable, 1'b1);
        check1("priority read suppressed", data_read_valid, 1'b0);
        check1("priority no error", access_error, 1'b0);
        @(posedge clk);
        @(negedge clk);
        data_read_req = 1'b0;
        data_write_req = 1'b0;

        @(negedge clk);
        data_read_req = 1'b1;
        #1;
        check1("priority write read-back valid", data_read_valid, 1'b1);
        check32("priority write read-back", data_read_data, 32'hA5A5A5A5);
        data_read_req = 1'b0;

        $display("TB_HARVARD_MEMORY_SYSTEM: PASS (%0d checks)", checks);
        $finish;
    end

endmodule
