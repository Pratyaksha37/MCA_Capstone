`timescale 1ns/1ps

// Directed test for data memory: initialized reads, write-edge timing,
// read-back, persistence, read-enable gating, and invalid addresses.
module tb_data_memory;

    reg        clk;
    reg [31:0] address;
    reg        read_enable;
    reg        write_enable;
    reg [31:0] write_data;
    wire [31:0] read_data;
    wire        valid;
    wire        write_accepted;
    integer     checks;

    data_memory dut (
        .clk            (clk),
        .address        (address),
        .read_enable    (read_enable),
        .write_enable   (write_enable),
        .write_data     (write_data),
        .read_data      (read_data),
        .valid          (valid),
        .write_accepted (write_accepted)
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
                $fatal(1, "data memory test failed");
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
                $fatal(1, "data memory test failed");
            end
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);

        clk = 1'b0;
        address = 32'd0;
        read_enable = 1'b0;
        write_enable = 1'b0;
        write_data = 32'd0;
        checks = 0;

        #10;

        // Initialized reads
        @(negedge clk);
        address = 32'd0;
        read_enable = 1'b1;
        #1;
        check1("initial read valid", valid, 1'b1);
        check32("initial word 0", read_data, 32'h00000011);

        @(negedge clk);
        address = 32'd4;
        #1;
        check32("initial word 1", read_data, 32'h00000022);

        @(negedge clk);
        address = 32'd60;
        #1;
        check32("initial word 15", read_data, 32'h00000456);

        // Read-enable gating
        @(negedge clk);
        read_enable = 1'b0;
        #1;
        check32("read disabled returns zero", read_data, 32'h00000000);

        // Write timing: old value before the edge, new value after the edge.
        @(negedge clk);
        address = 32'd8;
        read_enable = 1'b1;
        write_enable = 1'b1;
        write_data = 32'hCAFEBABE;
        #1;
        check1("write address valid", valid, 1'b1);
        check1("write accepted", write_accepted, 1'b1);
        check32("read before write edge", read_data, 32'h00000033);

        @(posedge clk);
        #1;
        check32("read after write edge", read_data, 32'hCAFEBABE);
        @(negedge clk);
        write_enable = 1'b0;
        read_enable = 1'b0;

        // Read the stored value back through a normal read.
        @(negedge clk);
        read_enable = 1'b1;
        #1;
        check32("write read-back", read_data, 32'hCAFEBABE);

        // Second write and persistence of the first write.
        @(negedge clk);
        address = 32'd12;
        write_enable = 1'b1;
        write_data = 32'h12345678;
        #1;
        check32("new address old value", read_data, 32'h00000044);
        @(posedge clk);
        @(negedge clk);
        write_enable = 1'b0;
        #1;
        check32("second write read-back", read_data, 32'h12345678);

        @(negedge clk);
        address = 32'd8;
        #1;
        check32("first write persisted", read_data, 32'hCAFEBABE);

        // Unaligned write must be rejected and must not corrupt word 1.
        @(negedge clk);
        address = 32'd6;
        write_enable = 1'b1;
        write_data = 32'hFFFFFFFF;
        #1;
        check1("unaligned write invalid", valid, 1'b0);
        check1("unaligned write not accepted", write_accepted, 1'b0);
        @(posedge clk);
        @(negedge clk);
        write_enable = 1'b0;
        address = 32'd4;
        #1;
        check32("unaligned write did not corrupt", read_data, 32'h00000022);

        // Out-of-range read must not select a word.
        @(negedge clk);
        address = 32'd64;
        #1;
        check1("out-of-range read invalid", valid, 1'b0);
        check32("out-of-range read zero", read_data, 32'h00000000);

        $display("TB_DATA_MEMORY: PASS (%0d checks)", checks);
        $finish;
    end

endmodule
