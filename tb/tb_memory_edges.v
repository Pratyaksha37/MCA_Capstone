`timescale 1ns/1ps
// Exhaustive control truth table, deterministic memory scoreboard, and shared
// invalid-address, pending-payload, synchronous-handshake, reset-abort checks.
module tb_memory_edges;
    reg clk = 0, reset = 1;
    reg [31:0] address = 0, wdata = 0;
    reg read_req = 0, write_req = 0;
    wire [31:0] rdata;
    wire valid, re, we, error;
    reg ir = 0, dr = 0, dw = 0;
    reg [31:0] ia = 0, da = 0, wd = 0;
    wire [31:0] idata, ddata;
    wire idone, ddone, si, sd, pending;
    reg [31:0] model [0:15];
    reg [31:0] before_word;
    integer checks = 0, i, j, k, n, seed = 4127;
    memory_controller c (.read_request(read_req), .write_request(write_req),
        .address_valid(valid), .read_enable(re), .write_enable(we), .access_error(error));
    data_memory m (.clk(clk), .address(address), .read_enable(re), .write_enable(we),
        .write_data(wdata), .read_data(rdata), .valid(valid), .write_accepted());
    shared_port_memory s (.clk(clk), .reset(reset), .instr_req(ir), .instr_addr(ia),
        .instr_rdata(idata), .instr_done(idone), .data_req(dr), .data_addr(da),
        .data_write(dw), .data_wdata(wd), .data_rdata(ddata), .data_done(ddone),
        .service_instr(si), .service_data(sd), .pending_data(pending));
    always #5 clk = ~clk;
    task check;
        input condition;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) $fatal(1, "edge check %0d failed", checks);
        end
    endtask
    initial begin
        $dumpfile("results/waveforms/tb_memory_edges.vcd");
        $dumpvars(0, tb_memory_edges);
        for (i=0; i<16; i=i+1) model[i] = m.mem[i];
        repeat (2) @(negedge clk);
        reset = 0;
        // Exhaust all request combinations, including idle invalid addresses.
        for (i=0; i<2; i=i+1)
            for (j=0; j<2; j=j+1)
                for (k=0; k<2; k=k+1) begin
                    address = i ? 0 : 64; read_req=j; write_req=k;
                    #1;
                    check(re == (i && j && !k));
                    check(we == (i && k));
                    check(error == (!i && (j || k)));
                end
        read_req=0; write_req=0;
        // Address low bits, high-bit aliasing, and all memory words.
        for (n=0; n<256; n=n+1) begin
            @(negedge clk);
            address = $random(seed) & 127;
            if (n % 8 == 0) address = 32'hfffffffc;
            read_req = 1; write_req = n % 2; wdata = $random(seed);
            #1;
            check(valid == (address < 64 && address[1:0] == 0));
            check(rdata == ((valid && !write_req) ? model[address[5:2]] : 0));
            if (valid && write_req) model[address[5:2]] = wdata;
            @(negedge clk);
            write_req = 0;
            #1;
            check(rdata == (valid ? model[address[5:2]] : 0));
        end
        for (i=0; i<16; i=i+1) begin
            address=i*4; #1; check(rdata == model[i]);
        end
        read_req=0;
        // Invalid shared requests never select or modify the array.
        for (i=0; i<4; i=i+1) begin
            @(negedge clk);
            ir=1; dr=1; dw=1; wd=32'hbadbad00;
            case (i)
                0: begin ia=2; da=66; end
                1: begin ia=64; da=0; end
                2: begin ia=32'hfffffffc; da=128; end
                3: begin ia=128; da=32'hfffffffc; end
            endcase
            #1; check(!si && !sd);
            @(negedge clk); check(!idone && !ddone && !pending);
        end
        ir=0; dr=0; dw=0;
        // Capture a pending write, then change the live payload. The snapshot
        // must be used; changing a captured request here stress-tests retention.
        @(negedge clk);
        ir=1; ia=0; dr=1; dw=1; da=64; wd=32'h12345678;
        @(negedge clk); check(idone && pending && !ddone);
        ir=0; da=68; wd=32'hffffffff;
        @(negedge clk);
        check(ddone && !pending && ddata == 32'h12345678);
        check(s.mem[16] == 32'h12345678 && s.mem[17] == 32'h22);
        // Hold through the next edge, as a synchronous requester does while
        // consuming done. There must be no replay using the changed payload.
        @(posedge clk);
        dr <= 0;
        @(negedge clk);
        check(!ddone && s.mem[17] == 32'h22);
        // Reset aborts a queued write and preserves previous memory contents.
        ir=1; ia=4; dr=1; dw=1; da=68; wd=32'haaaaaaaa;
        @(negedge clk); check(pending);
        reset=1;
        #1; check(!si && !sd);
        @(negedge clk);
        check(!pending && !idone && !ddone && s.mem[17] == 32'h22);
        ir=0; dr=0; reset=0;
        // Continuous instruction request still permits repeated data progress.
        @(negedge clk); ir=1; ia=0; dr=1; dw=0; da=64;
        @(negedge clk); check(idone && pending);
        @(negedge clk); check(ddone && ddata == 32'h12345678);
        ir=0; dr=0;
        $display("TB_MEMORY_EDGES: PASS (%0d checks)", checks);
        $finish;
    end
    initial begin #20000; $fatal(1, "edge test timeout"); end
endmodule
