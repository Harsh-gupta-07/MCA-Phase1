// =============================================================================
// File        : mac_unit.v
// Project     : Systolic Array Matrix Multiplication Accelerator (CSA-222)
// Owner       : Member 1
// Description : Signed fixed-point Multiply-Accumulate (MAC) unit.
//
//   acc <= acc + a * b          (when en = 1)
//   acc <= 0                    (when clear = 1, has priority over en)
//
// Number format
//   Operands a, b : signed Q4.4  (DATA_W = 8, FRAC_W = 4)  range [-8.0, +7.9375]
//   Product       : signed Q8.8  (2*DATA_W = 16 bits)
//   Accumulator   : signed Q24.8 (ACC_W = 32 bits) -> no overflow is possible
//                   for N <= 2^16 accumulations of the largest product.
//
// The multiplier is purely combinational; the accumulator is a single
// register stage, so one MAC completes every clock cycle (throughput = 1/cycle).
// =============================================================================
`timescale 1ns / 1ps

module mac_unit #(
    parameter DATA_W = 8,     // operand width (Q4.4)
    parameter ACC_W  = 32     // accumulator width (Q24.8)
) (
    input  wire                     clk,
    input  wire                     rst_n,   // asynchronous active-low reset
    input  wire                     clear,   // synchronous clear of accumulator
    input  wire                     en,      // accumulate enable
    input  wire signed [DATA_W-1:0] a,
    input  wire signed [DATA_W-1:0] b,
    output reg  signed [ACC_W-1:0]  acc
);

    // Full-precision signed product (Q8.8)
    wire signed [2*DATA_W-1:0] product;
    assign product = a * b;

    // Sign-extend product to accumulator width
    wire signed [ACC_W-1:0] product_ext;
    assign product_ext = {{(ACC_W-2*DATA_W){product[2*DATA_W-1]}}, product};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            acc <= {ACC_W{1'b0}};
        else if (clear)
            acc <= {ACC_W{1'b0}};
        else if (en)
            acc <= acc + product_ext;
    end

endmodule
