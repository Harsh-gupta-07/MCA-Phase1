// =============================================================================
// File        : input_skew.v
// Project     : Systolic Array Matrix Multiplication Accelerator (CSA-222)
// Owner       : Member 3
// Description : Diagonal skew (staggering) buffer for systolic input.
//
//   Lane k is delayed by k clock cycles:
//     lane 0 : no delay (wire)
//     lane 1 : 1 register
//     lane 2 : 2 registers
//     ...
//     lane N-1 : N-1 registers
//
//   This turns a "column at a time" input vector into the diagonal wavefront
//   required by the systolic array. The same module is used for the A side
//   (lanes = rows) and the B side (lanes = columns).
//   Total registers = DATA_W * N(N-1)/2.
// =============================================================================
`timescale 1ns / 1ps

module input_skew #(
    parameter N      = 4,
    parameter DATA_W = 8
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 clear,
    input  wire                 en,
    input  wire [N*DATA_W-1:0]  din,    // un-skewed vector
    output wire [N*DATA_W-1:0]  dout    // skewed vector
);

    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : g_lane
            if (k == 0) begin : g_nodelay
                assign dout[0 +: DATA_W] = din[0 +: DATA_W];
            end else if (k == 1) begin : g_delay1
                reg [DATA_W-1:0] sr;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      sr <= {DATA_W{1'b0}};
                    else if (clear)  sr <= {DATA_W{1'b0}};
                    else if (en)     sr <= din[k*DATA_W +: DATA_W];
                end
                assign dout[k*DATA_W +: DATA_W] = sr;
            end else begin : g_delayk
                // k-stage shift register, newest sample in the low slice
                reg [k*DATA_W-1:0] sr;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      sr <= {(k*DATA_W){1'b0}};
                    else if (clear)  sr <= {(k*DATA_W){1'b0}};
                    else if (en)     sr <= {sr[(k-1)*DATA_W-1:0], din[k*DATA_W +: DATA_W]};
                end
                assign dout[k*DATA_W +: DATA_W] = sr[k*DATA_W-1 -: DATA_W];
            end
        end
    endgenerate

endmodule
