// =============================================================================
// tb_fir4.sv -- Self-checking testbench for the fir4 FIR filter
//
// Mode A (default): drive tb/stim_vectors.hex, compare every valid output
//                   against tb/expected_vectors.hex (from MATLAB).
// Mode B (fallback, if the hex files are missing): inline impulse, step.
// Both modes finish with a reset test.
//
// Compile-time options:
//   -define TIMING       gate-level timing sim: SDF annotation + 200 ps input delay
//   -define SDF_FILE=... SDF path used with TIMING
//   -define FUNCTIONAL   only changes the banner text (functional GLS)
// =============================================================================
`timescale 1ns/1ps

module tb_fir4;
    localparam real CLK_PERIOD = 3.333;     // 300 MHz
    localparam int  PIPE_LAT   = 3;
    localparam int  MAX_VEC    = 4096;

    logic              clk, rst_b, valid_in, valid_out;
    logic              scan_en, test_mode, scan_in, scan_out;
    logic signed [7:0]  x;
    logic signed [10:0] y;

    fir4 dut (.*);

`ifdef TIMING
    `ifndef SDF_FILE
        `define SDF_FILE "innovus/output/fir4.sdf"
    `endif
    initial begin
        $display("[%0t] SDF: %s", $time, `SDF_FILE);
        $sdf_annotate(`SDF_FILE, dut);
    end
    localparam real INPUT_DLY = 0.2;        // 200 ps after each posedge clk
`else
    localparam real INPUT_DLY = 0;
`endif

    initial clk = 0;
    always #(CLK_PERIOD / 2.0) clk = ~clk;

    int err_count  = 0;
    int test_count = 0;

    // Watchdog
    initial begin
        #(CLK_PERIOD * 20000);
        $display("[%0t] FATAL: watchdog timeout", $time);
        $fatal(1);
    end

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    task automatic do_reset();
        rst_b = 0; valid_in = 0; x = 0;
        scan_en = 0; test_mode = 0; scan_in = 0;
        repeat (4) @(posedge clk);
        #(INPUT_DLY);
        rst_b = 1;
        @(posedge clk);
    endtask

    task automatic t_pass(string tag, string msg);
        $display("[%0t] PASS %-20s %s", $time, tag, msg);
    endtask

    task automatic t_fail(string tag, string msg);
        err_count++;
        $display("[%0t] FAIL %-20s %s", $time, tag, msg);
    endtask

    // -------------------------------------------------------------------------
    // Mode A: MATLAB vectors
    // -------------------------------------------------------------------------
    logic signed [7:0]  stim_mem [0:MAX_VEC-1];
    logic signed [10:0] exp_mem  [0:MAX_VEC-1];
    int vec_len;
    bit vectors_loaded;

    task automatic load_vectors();
        vectors_loaded = 0;
        $readmemh("tb/stim_vectors.hex",     stim_mem);
        $readmemh("tb/expected_vectors.hex", exp_mem);
        vec_len = MAX_VEC;
        for (int i = 0; i < MAX_VEC; i++)
            if ($isunknown(stim_mem[i])) begin vec_len = i; break; end
        if (vec_len > 0 && vec_len < MAX_VEC) begin
            $display(" Loaded %0d vectors", vec_len);
            vectors_loaded = 1;
        end
    endtask

    task automatic test_vectors();
        int out_idx, mismatches;
        test_count++;
        do_reset();
        out_idx = 0; mismatches = 0;
        for (int cyc = 0; cyc < vec_len + PIPE_LAT + 4; cyc++) begin
            @(posedge clk);
            #(INPUT_DLY);
            if (cyc < vec_len) begin
                valid_in <= 1; x <= stim_mem[cyc];
            end else begin
                valid_in <= 0; x <= 8'sd0;
            end
            @(negedge clk);
            if (valid_out && out_idx < vec_len) begin
                if (y !== exp_mem[out_idx]) begin
                    if (mismatches < 10)
                        $display("[%0t]    mismatch out[%0d]: got %0d exp %0d",
                                 $time, out_idx, y, exp_mem[out_idx]);
                    mismatches++;
                end
                out_idx++;
            end
        end
        if (mismatches > 0)
            t_fail("matlab-vectors", $sformatf("%0d/%0d mismatches", mismatches, out_idx));
        else if (out_idx != vec_len)
            t_fail("matlab-vectors",
                   $sformatf("collected %0d outputs, expected %0d", out_idx, vec_len));
        else
            t_pass("matlab-vectors", $sformatf("%0d/%0d outputs matched", out_idx, vec_len));
    endtask

    // -------------------------------------------------------------------------
    // Mode B: inline tests
    // -------------------------------------------------------------------------
    task automatic test_impulse();
        logic signed [7:0] stim [4];
        int expected [4];
        int out_idx;
        stim     = '{8'sd64, 8'sd0, 8'sd0, 8'sd0};
        expected = '{8, 24, 24, 8};
        test_count++;
        do_reset();
        out_idx = 0;
        for (int cyc = 0; cyc < 4 + PIPE_LAT + 2; cyc++) begin
            @(posedge clk);
            #(INPUT_DLY);
            if (cyc < 4) begin
                valid_in <= 1; x <= stim[cyc];
            end else begin
                valid_in <= 0; x <= 8'sd0;
            end
            @(negedge clk);
            if (valid_out && out_idx < 4) begin
                if (y !== expected[out_idx]) begin
                    t_fail("impulse", $sformatf("y[%0d]=%0d expected %0d",
                                                out_idx, y, expected[out_idx]));
                    return;
                end
                out_idx++;
            end
        end
        if (out_idx != 4)
            t_fail("impulse", $sformatf("got %0d outputs, expected 4", out_idx));
        else
            t_pass("impulse", "y = {8, 24, 24, 8}");
    endtask

    task automatic test_step();
        logic signed [10:0] last_y;
        test_count++;
        do_reset();
        last_y = 0;
        for (int cyc = 0; cyc < 16; cyc++) begin
            @(posedge clk);
            #(INPUT_DLY);
            if (cyc < 12) begin
                valid_in <= 1; x <= 8'sd127;
            end else begin
                valid_in <= 0;
            end
            @(negedge clk);
            if (valid_out) last_y = y;
        end
        if (last_y !== 11'sd127)
            t_fail("step", $sformatf("y=%0d expected 127", last_y));
        else
            t_pass("step", "y = 127 at steady state");
    endtask

    // -------------------------------------------------------------------------
    // Reset test (both modes): async reset must clear valid_out
    // -------------------------------------------------------------------------
    task automatic test_reset();
        test_count++;
        do_reset();
        for (int cyc = 0; cyc < 6 + PIPE_LAT + 2; cyc++) begin
            @(posedge clk);
            #(INPUT_DLY);
            if (cyc < 6) begin
                valid_in <= 1; x <= 8'sd100;
            end else begin
                valid_in <= 0;
            end
        end
        @(posedge clk); #(INPUT_DLY);
        rst_b = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        if (valid_out !== 1'b0)
            t_fail("reset", $sformatf("valid_out=%b expected 0", valid_out));
        else
            t_pass("reset", "valid_out=0 during reset");
        @(posedge clk);
        rst_b = 1;
    endtask

    // -------------------------------------------------------------------------
    // Main sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("============================================================");
`ifdef TIMING
        $display(" fir4 testbench -- GLS TIMING (SDF)");
`elsif FUNCTIONAL
        $display(" fir4 testbench -- GLS FUNCTIONAL");
`else
        $display(" fir4 testbench -- RTL SIMULATION");
`endif
        $display(" Clock: %0.3f ns (%0.1f MHz)", CLK_PERIOD, 1000.0 / CLK_PERIOD);
        $display("============================================================");
        load_vectors();
        if (vectors_loaded) begin
            test_vectors();
            test_reset();
        end else begin
            $display(" Hex vectors not found -- running inline tests");
            test_impulse();
            test_step();
            test_reset();
        end
        $display("============================================================");
        $display(" Summary: %0d test(s), %0d failure(s)", test_count, err_count);
        if (err_count == 0) $display(" TEST PASSED");
        else                $display(" TEST FAILED");
        $display("============================================================");
        $finish;
    end
endmodule
