// =============================================================================
// fir4.sv -- 4-tap symmetric FIR low-pass filter
// Coefficients: [1, 3, 3, 1] / 8
// y[n] = ( x[n] + x[n-3] + 3*(x[n-1] + x[n-2]) ) / 8
//
//   stage 1: sum_a = x[n] + x[n-3], sum_b = x[n-1] + x[n-2]   (9-bit)
//   stage 2: prod_b = 3 * sum_b (11-bit), sum_a passes through
//   stage 3: result = (sum_a + prod_b) >>> 3                  (8-bit)
//
// 3-stage pipeline, 3-clock latency, async active-low reset (rst_b).
// =============================================================================
`timescale 1ns / 1ps

module fir4_stage1 (
    input  wire       clk,
    input  wire       rst_b,
    input  wire       valid_in,
    input  wire [7:0] x0, x1, x2, x3,   // signed samples, sign in MSB
    output reg  [8:0] sum_a,            // x0 + x3, range -256..254
    output reg  [8:0] sum_b,            // x1 + x2, range -256..254
    output reg        valid_out
);
    wire [8:0] e0 = {x0[7], x0};
    wire [8:0] e1 = {x1[7], x1};
    wire [8:0] e2 = {x2[7], x2};
    wire [8:0] e3 = {x3[7], x3};

    // x0 and x3 are both multiplied by 1, so they can be added first
    wire [8:0] s0 = e0 + e3;
    // x1 and x2 are both multiplied by 3, so they can be added first
    wire [8:0] s1 = e1 + e2;

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            sum_a     <= 9'd0;
            sum_b     <= 9'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            sum_a     <= s0;
            sum_b     <= s1;
        end
    end
endmodule

module fir4_stage2 (
    input  wire        clk,
    input  wire        rst_b,
    input  wire        valid_in,
    input  wire [8:0]  sum_a, sum_b,
    output reg  [8:0]  prod_a,          // multiplied by 1: passthrough
    output reg  [10:0] prod_b,          // 3 * sum_b, range -768..762
    output reg         valid_out
);
    wire [10:0] b_ext   = {{2{sum_b[8]}}, sum_b};
    wire [10:0] b_shift = {b_ext[9:0], 1'b0};   // b * 2
    wire [10:0] b_add   = b_shift + b_ext;      // b * 3

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            prod_a    <= 9'd0;
            prod_b    <= 11'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            prod_a    <= sum_a;
            prod_b    <= b_add;
        end
    end
endmodule

module fir4_stage3 (
    input  wire        clk,
    input  wire        rst_b,
    input  wire        valid_in,
    input  wire [8:0]  prod_a,          // range -256..254
    input  wire [10:0] prod_b,          // range -768..762
    output reg  [7:0]  result,          // (prod_a + prod_b) >>> 3
    output reg         valid_out
);
    // Sum range is -1024..1016, which fits 11 signed bits
    wire [10:0] a_ext = {{2{prod_a[8]}}, prod_a};
    wire [10:0] total = a_ext + prod_b;

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            result    <= 8'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            result    <= total[10:3];
        end
    end
endmodule

module fir4 (
    input  wire        clk,
    input  wire        rst_b,
    input  wire        valid_in,
    input  wire [7:0]  x,
    output wire        valid_out,
    output wire [10:0] y,
    input  wire        scan_en,
    input  wire        test_mode,
    input  wire        scan_in,
    output wire        scan_out
);
    reg [7:0] delay_line [3:1];

    always @(posedge clk or negedge rst_b) begin
        if (!rst_b) begin
            delay_line[1] <= 8'd0;
            delay_line[2] <= 8'd0;
            delay_line[3] <= 8'd0;
        end else if (valid_in) begin
            delay_line[1] <= x;
            delay_line[2] <= delay_line[1];
            delay_line[3] <= delay_line[2];
        end
    end

    wire [8:0] stage1_out_a;
    wire [8:0] stage1_out_b;
    wire       stage1_out_valid;
    fir4_stage1 STAGE1 (
        .clk(clk), .rst_b(rst_b), .valid_in(valid_in),
        .x0(x), .x1(delay_line[1]), .x2(delay_line[2]), .x3(delay_line[3]),
        .sum_a(stage1_out_a), .sum_b(stage1_out_b), .valid_out(stage1_out_valid)
    );

    wire [8:0]  stage2_out_a;
    wire [10:0] stage2_out_b;
    wire        stage2_out_valid;
    fir4_stage2 STAGE2 (
        .clk(clk), .rst_b(rst_b), .valid_in(stage1_out_valid),
        .sum_a(stage1_out_a), .sum_b(stage1_out_b),
        .prod_a(stage2_out_a), .prod_b(stage2_out_b), .valid_out(stage2_out_valid)
    );

    wire [7:0] stage3_result;
    wire       stage3_out_valid;
    fir4_stage3 STAGE3 (
        .clk(clk), .rst_b(rst_b), .valid_in(stage2_out_valid),
        .prod_a(stage2_out_a), .prod_b(stage2_out_b),
        .result(stage3_result), .valid_out(stage3_out_valid)
    );

    assign y         = {{3{stage3_result[7]}}, stage3_result};
    assign valid_out = stage3_out_valid;

`ifndef DFT_INSERTION
    assign scan_out = 1'b0;
`endif
endmodule
