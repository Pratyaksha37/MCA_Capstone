`timescale 1ns/1ps

// Performance comparison using actual RTL request/completion signals.
//
// Workload: request one instruction fetch and one data read at the same time,
// then wait for both results.  One clock cycle is the interval between rising
// edges.  The counter is incremented on each observed rising edge until the
// completion flags (derived from real valid/done signals) show that both
// operations finished.
//
// Harvard: both independent ports complete during the request cycle.
// Shared : instruction completes first; retained data completes one cycle later.
module tb_memory_comparison;

    reg clk;
    reg reset;

    // Harvard interface
    wire [31:0] h_pc;
    wire [31:0] h_instr;
    wire        h_instr_valid;
    reg  [31:0] h_data_addr;
    reg         h_data_read_req;
    reg         h_data_write_req;
    reg  [31:0] h_data_wdata;
    wire [31:0] h_data_rdata;
    wire        h_data_valid;
    wire        h_data_write_en;
    wire        h_access_error;

    // Shared-memory interface
    reg         s_instr_req;
    reg  [31:0] s_instr_addr;
    wire [31:0] s_instr_rdata;
    wire        s_instr_done;
    reg         s_data_req;
    reg  [31:0] s_data_addr;
    reg         s_data_write;
    reg  [31:0] s_data_wdata;
    wire [31:0] s_data_rdata;
    wire        s_data_done;
    wire        s_service_instr;
    wire        s_service_data;
    wire        s_pending_data;

    localparam [31:0] INSTR_WORD_1 = 32'h00100093;
    localparam [31:0] DATA_WORD_0  = 32'h00000011;

    integer checks;
    integer harvard_cycles;
    integer shared_cycles;
    integer guard;
    real    speedup;
    integer fd;

    reg h_instr_seen;
    reg h_data_seen;
    reg s_instr_seen;
    reg s_data_seen;

    reg [31:0] harvard_instr_observed;
    reg [31:0] harvard_data_observed;
    reg [31:0] shared_instr_observed;
    reg [31:0] shared_data_observed;

    harvard_memory_system harvard (
        .clk               (clk),
        .reset             (reset),
        .pc_out            (h_pc),
        .instruction_out   (h_instr),
        .instruction_valid (h_instr_valid),
        .data_address      (h_data_addr),
        .data_read_req     (h_data_read_req),
        .data_write_req    (h_data_write_req),
        .data_write_data   (h_data_wdata),
        .data_read_data    (h_data_rdata),
        .data_read_valid   (h_data_valid),
        .data_write_enable (h_data_write_en),
        .access_error      (h_access_error)
    );

    shared_port_memory shared (
        .clk           (clk),
        .reset         (reset),
        .instr_req     (s_instr_req),
        .instr_addr    (s_instr_addr),
        .instr_rdata   (s_instr_rdata),
        .instr_done    (s_instr_done),
        .data_req      (s_data_req),
        .data_addr     (s_data_addr),
        .data_write    (s_data_write),
        .data_wdata    (s_data_wdata),
        .data_rdata    (s_data_rdata),
        .data_done     (s_data_done),
        .service_instr (s_service_instr),
        .service_data  (s_service_data),
        .pending_data  (s_pending_data)
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
                $fatal(1, "performance comparison test failed");
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
                $fatal(1, "performance comparison test failed");
            end
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/tb_memory_comparison.vcd");
        $dumpvars(0, tb_memory_comparison);

        clk = 1'b0;
        reset = 1'b1;
        h_data_addr = 32'd0;
        h_data_read_req = 1'b0;
        h_data_write_req = 1'b0;
        h_data_wdata = 32'd0;
        s_instr_req = 1'b0;
        s_instr_addr = 32'd0;
        s_data_req = 1'b0;
        s_data_addr = 32'd0;
        s_data_write = 1'b0;
        s_data_wdata = 32'd0;
        checks = 0;
        harvard_cycles = 0;
        shared_cycles = 0;

        #12;
        @(negedge clk);
        reset = 1'b0;

        // Let one edge pass; the PC is now 4, so instruction word 1 is fetched.
        @(negedge clk);
        check32("Harvard PC at request", h_pc, 32'd4);

        // ---------------- Harvard measurement ----------------
        // Requests are stable at this negedge.  The counter will advance on
        // every following rising edge until both valid signs are observed.
        h_data_addr = 32'd0;
        h_data_read_req = 1'b1;
        #1;
        check1("Harvard instruction valid", h_instr_valid, 1'b1);
        check1("Harvard data valid", h_data_valid, 1'b1);
        check32("Harvard instruction value", h_instr, INSTR_WORD_1);
        check32("Harvard data value", h_data_rdata, DATA_WORD_0);

        h_instr_seen = 1'b0;
        h_data_seen = 1'b0;
        harvard_cycles = 0;
        guard = 0;
        while (!(h_instr_seen && h_data_seen) && (guard < 20)) begin
            @(posedge clk);
            harvard_cycles = harvard_cycles + 1;
            // Sample the instruction consumed at this edge, before the PC's
            // nonblocking update advances to the next instruction.
            if (h_instr_valid) begin
                harvard_instr_observed = h_instr;
                h_instr_seen = 1'b1;
            end
            if (h_data_valid) begin
                harvard_data_observed = h_data_rdata;
                h_data_seen = 1'b1;
            end
            @(negedge clk);
            guard = guard + 1;
        end

        if (!(h_instr_seen && h_data_seen))
            $fatal(1, "Harvard accesses did not complete");
        check32("Harvard observed instruction", harvard_instr_observed, INSTR_WORD_1);
        check32("Harvard observed data", harvard_data_observed, DATA_WORD_0);
        h_data_read_req = 1'b0;

        // ---------------- Shared-memory measurement ----------------
        @(negedge clk);
        s_instr_addr = 32'd4;
        s_instr_req = 1'b1;
        s_data_addr = 32'h00000040;
        s_data_req = 1'b1;
        s_data_write = 1'b0;

        s_instr_seen = 1'b0;
        s_data_seen = 1'b0;
        shared_cycles = 0;
        guard = 0;
        while (!(s_instr_seen && s_data_seen) && (guard < 20)) begin
            @(posedge clk);
            shared_cycles = shared_cycles + 1;
            @(negedge clk);

            if (s_instr_done && !s_instr_seen) begin
                shared_instr_observed = s_instr_rdata;
                s_instr_seen = 1'b1;
                s_instr_req = 1'b0;
                check1("Shared instruction completes first", s_data_done, 1'b0);
                check1("Shared data request retained", s_pending_data, 1'b1);
            end
            if (s_data_done && !s_data_seen) begin
                shared_data_observed = s_data_rdata;
                s_data_seen = 1'b1;
            end
            guard = guard + 1;
        end

        if (!(s_instr_seen && s_data_seen))
            $fatal(1, "Shared-memory accesses did not complete");
        check32("Shared observed instruction", shared_instr_observed, INSTR_WORD_1);
        check32("Shared observed data", shared_data_observed, DATA_WORD_0);

        s_instr_req = 1'b0;
        s_data_req = 1'b0;
        @(negedge clk);
        check1("Shared data done pulse ends", s_data_done, 1'b0);

        // ---------------- Final checks and report ----------------
        check32("Harvard measured cycles", harvard_cycles, 1);
        check32("Shared measured cycles", shared_cycles, 2);

        speedup = shared_cycles * 1.0 / harvard_cycles;

        $display("PERFORMANCE_RESULT:");
        $display("  workload                   = 1 instruction fetch + 1 data read (simultaneous)");
        $display("  Harvard completion cycles  = %0d", harvard_cycles);
        $display("  Shared completion cycles   = %0d", shared_cycles);
        $display("  Speedup (shared/harvard)   = %0.2f", speedup);
        $display("  Harvard throughput         = %0.2f operations/cycle", 2.0 / harvard_cycles);
        $display("  Shared throughput          = %0.2f operations/cycle", 2.0 / shared_cycles);
        $display("  Harvard results            = instr %08h, data %08h", harvard_instr_observed, harvard_data_observed);
        $display("  Shared results             = instr %08h, data %08h", shared_instr_observed, shared_data_observed);

        fd = $fopen("results/performance/performance_summary.txt", "w");
        if (fd == 0) begin
            $display("WARNING: could not open results/performance/performance_summary.txt");
        end else begin
            $fdisplay(fd, "# Memory Hierarchy Performance Measurement");
            $fdisplay(fd, "");
            $fdisplay(fd, "Workload: one instruction fetch and one data read requested simultaneously.");
            $fdisplay(fd, "Counting: rising edges counted until both completion signals are observed.");
            $fdisplay(fd, "");
            $fdisplay(fd, "| Architecture | Completion cycles | Throughput (operations/cycle) |");
            $fdisplay(fd, "|---|---:|---:|");
            $fdisplay(fd, "| Harvard (separate ports) | %0d | %0.2f |", harvard_cycles, 2.0 / harvard_cycles);
            $fdisplay(fd, "| Shared single port | %0d | %0.2f |", shared_cycles, 2.0 / shared_cycles);
            $fdisplay(fd, "");
            $fdisplay(fd, "Speedup = shared cycles / Harvard cycles = %0d / %0d = %0.2f", shared_cycles, harvard_cycles, speedup);
            $fdisplay(fd, "");
            $fdisplay(fd, "Harvard observed: instruction %08h, data %08h", harvard_instr_observed, harvard_data_observed);
            $fdisplay(fd, "Shared observed:  instruction %08h, data %08h", shared_instr_observed, shared_data_observed);
            $fdisplay(fd, "Both requests completed and returned the expected values.");
            $fclose(fd);
        end

        $display("TB_MEMORY_COMPARISON: PASS (%0d checks)", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "performance comparison timed out");
    end

endmodule
