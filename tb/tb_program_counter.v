`timescale 1ns/1ps

// Directed test for the program counter: reset value, reset release,
// consecutive increments, and reset re-assertion.
module tb_program_counter;

    reg        clk;
    reg        reset;
    wire [31:0] pc;
    integer    checks;
    integer    i;
    reg [31:0] expected;

    program_counter dut (
        .clk   (clk),
        .reset (reset),
        .pc    (pc)
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
                $fatal(1, "program counter test failed");
            end
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/tb_program_counter.vcd");
        $dumpvars(0, tb_program_counter);

        clk = 1'b0;
        reset = 1'b1;
        checks = 0;
        expected = 32'd0;

        #12;
        check32("PC after reset", pc, 32'd0);

        @(negedge clk);
        reset = 1'b0;

        // Five consecutive rising edges must produce 4, 8, 12, 16, 20.
        expected = 32'd4;
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge clk);
            check32("PC increment", pc, expected);
            expected = expected + 32'd4;
        end

        // Reset must work again after the PC has advanced.
        @(negedge clk);
        reset = 1'b1;
        @(negedge clk);
        check32("PC reset re-asserted", pc, 32'd0);

        @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        check32("PC first increment after reset", pc, 32'd4);

        $display("TB_PROGRAM_COUNTER: PASS (%0d checks)", checks);
        $finish;
    end

endmodule
