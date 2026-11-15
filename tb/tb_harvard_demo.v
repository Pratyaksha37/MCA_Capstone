`timescale 1ns/1ps
module tb_harvard_demo;
    reg clk = 0;
    reg reset = 1;
    wire [31:0] pc, instruction, retired, result;
    wire halted, fault, data_read, data_write;
    integer cycles = 0;
    integer accesses = 0;
    integer checks = 0;
    reg [31:0] expected [0:6];
    harvard_demo dut (.clk(clk), .reset(reset), .pc(pc),
        .instruction(instruction), .halted(halted), .fault(fault),
        .retired(retired), .result(result), .data_read(data_read), .data_write(data_write));
    always #5 clk = ~clk;
    task check;
        input condition;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) $fatal(1, "demo check %0d failed, pc=%h", checks, pc);
        end
    endtask
    initial begin
        $dumpfile("results/waveforms/tb_harvard_demo.vcd");
        $dumpvars(0, tb_harvard_demo);
        expected[0]=32'h00500093; expected[1]=32'h00102023;
        expected[2]=32'h00002103; expected[3]=32'hfff10113;
        expected[4]=32'h02202e23; expected[5]=32'h03c02183;
        expected[6]=32'h00100073;
        repeat (2) @(negedge clk);
        reset = 0;
        while (!halted && cycles < 16) begin
            #1;
            check(pc == cycles * 4);
            check(instruction == expected[cycles]);
            if (data_read || data_write) accesses = accesses + 1;
            @(negedge clk);
            cycles = cycles + 1;
            check(!fault);
        end
        check(halted && cycles == 7 && retired == 7);
        check(accesses == 4);
        check(result == 4 && dut.regs[1] == 5 && dut.regs[2] == 4);
        check(dut.regs[0] == 0);
        check(dut.dmem.mem[0] == 5 && dut.dmem.mem[15] == 4);
        repeat (2) @(negedge clk);
        check(pc == 24 && retired == 7 && !data_read && !data_write);
        // Reset clears execution state but preserves RAM and suppresses stores.
        reset = 1;
        @(negedge clk);
        check(pc == 0 && retired == 0 && !halted && !fault && result == 0);
        check(dut.dmem.mem[0] == 5 && dut.dmem.mem[15] == 4);
        // Execute an attempted write to x0, then halt.
        dut.imem.mem[0] = 32'hfff00013; // addi x0, x0, -1
        dut.imem.mem[1] = 32'h00100073;
        reset = 0;
        @(negedge clk);
        check(dut.regs[0] == 0 && pc == 4);
        @(negedge clk);
        check(halted && retired == 2 && !fault);
        // Unsupported instruction must fault without retiring or writing.
        reset = 1;
        @(negedge clk);
        dut.imem.mem[0] = 0;
        reset = 0;
        @(negedge clk);
        check(fault && !halted && retired == 0 && pc == 0);
        @(negedge clk);
        check(fault && pc == 0 && retired == 0 && !data_read && !data_write);
        // Unaligned load must fault.
        reset = 1;
        @(negedge clk);
        dut.imem.mem[0] = 32'h00202083; // lw x1, 2(x0)
        reset = 0;
        @(negedge clk);
        check(fault && retired == 0 && dut.regs[1] == 0);
        // Out-of-range store must fault without corrupting RAM.
        reset = 1;
        @(negedge clk);
        dut.imem.mem[0] = 32'h04102023; // sw x1, 64(x0)
        reset = 0;
        @(negedge clk);
        check(fault && retired == 0 && !data_write);
        check(dut.dmem.mem[0] == 5 && dut.dmem.mem[15] == 4);
        $display("PROGRAM_RESULT: 7 instructions / %0d cycles; %0d concurrent data accesses; x3=%0d", cycles, accesses, 4);
        $display("TB_HARVARD_DEMO: PASS (%0d checks)", checks);
        $finish;
    end
    initial begin #10000; $fatal(1, "demo timeout"); end
endmodule
