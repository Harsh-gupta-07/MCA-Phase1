// =============================================================================
// File        : matrix_buffer.v
// Project     : Systolic Array Matrix Multiplication Accelerator (CSA-222)
// Owner       : Member 4
// Description : Input buffers + matrix data interface.
//
//   Holds operand matrices A (N x N) and B (N x N) in registers.
//
//   Write side (host / testbench interface)
//     wr_en   : write strobe
//     wr_sel  : 0 -> matrix A, 1 -> matrix B
//     wr_addr : row-major element address = row*N + col
//     wr_data : signed Q4.4 element
//
//   Read side (towards the systolic array, driven by the controller)
//     feed    : 1 -> present step k, 0 -> present zeros (pipeline bubbles)
//     k_idx   : step index 0..N-1
//     a_vec   : lane i = A[i][k]   (column k of A, one element per row)
//     b_vec   : lane j = B[k][j]   (row    k of B, one element per column)
// =============================================================================
`timescale 1ns / 1ps

module matrix_buffer #(
    parameter N      = 4,
    parameter DATA_W = 8,
    parameter AW     = (N*N > 1) ? $clog2(N*N) : 1,   // element address width
    parameter KW     = (N   > 1) ? $clog2(N)   : 1    // step index width
) (
    input  wire                 clk,
    input  wire                 rst_n,
    // write interface
    input  wire                 wr_en,
    input  wire                 wr_sel,
    input  wire [AW-1:0]        wr_addr,
    input  wire [DATA_W-1:0]    wr_data,
    // read interface
    input  wire                 feed,
    input  wire [KW-1:0]        k_idx,
    output wire [N*DATA_W-1:0]  a_vec,
    output wire [N*DATA_W-1:0]  b_vec
);

    // Flattened row-major storage: element e = row*N + col
    reg [N*N*DATA_W-1:0] a_mem;
    reg [N*N*DATA_W-1:0] b_mem;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_mem <= {(N*N*DATA_W){1'b0}};
            b_mem <= {(N*N*DATA_W){1'b0}};
        end else if (wr_en) begin
            if (wr_sel == 1'b0)
                a_mem[wr_addr*DATA_W +: DATA_W] <= wr_data;
            else
                b_mem[wr_addr*DATA_W +: DATA_W] <= wr_data;
        end
    end

    genvar l;
    generate
        for (l = 0; l < N; l = l + 1) begin : g_lane
            // A side: lane l carries A[l][k]  -> element index l*N + k
            assign a_vec[l*DATA_W +: DATA_W] =
                feed ? a_mem[(l*N + k_idx)*DATA_W +: DATA_W] : {DATA_W{1'b0}};
            // B side: lane l carries B[k][l]  -> element index k*N + l
            assign b_vec[l*DATA_W +: DATA_W] =
                feed ? b_mem[(k_idx*N + l)*DATA_W +: DATA_W] : {DATA_W{1'b0}};
        end
    endgenerate

endmodule
