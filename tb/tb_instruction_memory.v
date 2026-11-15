`timescale 1ns/1ps

// Directed test for instruction memory: all 16 initialized words, byte-address
// to word-index mapping, and defined behavior for unaligned/out-of-range reads.
module tb_instruction_memory;

    reg        clk;
    reg [31:0] address;
    wire [31:0] instruction;
    wire        valid;
    integer     checks;
    integer     i;
    reg [31:0] expected [0:15];

    instruction_memory dut (
        .address     (address),
        .instruction (instruction),
        .valid       (valid)
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
                $fatal(1, "instruction memory test failed");
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
                $fatal(1, "instruction memory test failed");
            end
        end
    endtask

    initial begin
        expected[0]  = 32'h00000013;
        expected[1]  = 32'h00100093;
        expected[2]  = 32'h00200113;
        expected[3]  = 32'h00300193;
        expected[4]  = 32'h00400213;
        expected[5]  = 32'h00500293;
        expected[6]  = 32'h00600313;
        expected[7]  = 32'h00700393;
        expected[8]  = 32'h00800413;
        expected[9]  = 32'h00900493;
        expected[10] = 32'h00A00513;
        expected[11] = 32'h00B00593;
        expected[12] = 32'h00C00613;
        expected[13] = 32'h00D00693;
        expected[14] = 32'h00E00713;
        expected[15] = 32'h00F00793;
    end

    initial begin
        $dumpfile("results/waveforms/tb_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory);

        clk = 1'b0;
        address = 32'd0;
        checks = 0;

        #10;

        // Read every word: byte address 4*i maps to word i.
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);
            address = i * 4;
            #1;
            check1("instruction valid", valid, 1'b1);
            check32("instruction word", instruction, expected[i]);
        end

        // Unaligned address must not select a word.
        @(negedge clk);
        address = 32'd2;
        #1;
        check1("unaligned valid low", valid, 1'b0);
        check32("unaligned returns zero", instruction, 32'h00000000);

        // First address beyond the 16-word range.
        @(negedge clk);
        address = 32'd64;
        #1;
        check1("out-of-range valid low", valid, 1'b0);
        check32("out-of-range returns zero", instruction, 32'h00000000);

        // High address with the same low bits must also be rejected.
        @(negedge clk);
        address = 32'hFFFF_FFFC;
        #1;
        check1("high address valid low", valid, 1'b0);
        check32("high address returns zero", instruction, 32'h00000000);

        $display("TB_INSTRUCTION_MEMORY: PASS (%0d checks)", checks);
        $finish;
    end

endmodule
