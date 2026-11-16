// =============================================================================
// File        : systolic_top.v
// Project     : Systolic Array Matrix Multiplication Accelerator (CSA-222)
// Owner       : Member 4 (integration with Member 5)
// Description : Top level of the Phase-I accelerator.
//
//   +----------------+   a_vec   +-----------+  a_west  +------------------+
//   |                |---------->| A  skew   |--------->|                  |
//   | matrix_buffer  |   b_vec   +-----------+  b_north |  systolic_array  |--> c_flat
//   | (A, B storage) |---------->| B  skew   |--------->|   N x N  PEs     |     |
//   +----------------+           +-----------+          +------------------+     v
//          ^  ^                       ^                         ^           output read
//   wr_*  _|  | feed,k_idx            | clear, en               |           mux (rd_addr)
//             +-----------+-----------+-------------------------+
//                         |  systolic_controller (FSM)  |<-- start / --> busy, done
//
//   Usage
//     1. Write the N*N elements of A (wr_sel=0) and B (wr_sel=1).
//     2. Pulse start for one cycle.
//     3. Wait for done.
//     4. Read C[r][c] by setting rd_addr = r*N + c (combinational read).
//        Results are raw Q24.8 (divide by 2^8 for the real value).
// =============================================================================
`timescale 1ns / 1ps

module systolic_top #(
    parameter N      = 4,
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter AW     = (N*N > 1) ? $clog2(N*N) : 1,
    parameter KW     = (N   > 1) ? $clog2(N)   : 1
) (
    input  wire                     clk,
    input  wire                     rst_n,
    // control / status
    input  wire                     start,
    output wire                     busy,
    output wire                     done,
    // matrix data interface - write operands
    input  wire                     wr_en,
    input  wire                     wr_sel,      // 0 = A, 1 = B
    input  wire [AW-1:0]            wr_addr,     // row*N + col
    input  wire [DATA_W-1:0]        wr_data,     // Q4.4
    // matrix data interface - read result
    input  wire [AW-1:0]            rd_addr,     // row*N + col
    output wire signed [ACC_W-1:0]  rd_data      // Q24.8
);

    wire          clear, en, feed;
    wire [KW-1:0] k_idx;

    wire [N*DATA_W-1:0]  a_vec, b_vec;      // from buffers (un-skewed)
    wire [N*DATA_W-1:0]  a_west, b_north;   // to array (skewed)
    wire [N*N*ACC_W-1:0] c_flat;

    systolic_controller #(.N(N), .KW(KW)) u_ctrl (
        .clk   (clk),   .rst_n (rst_n), .start (start),
        .clear (clear), .en    (en),    .feed  (feed),
        .k_idx (k_idx), .busy  (busy),  .done  (done)
    );

    matrix_buffer #(.N(N), .DATA_W(DATA_W), .AW(AW), .KW(KW)) u_buf (
        .clk     (clk),     .rst_n   (rst_n),
        .wr_en   (wr_en),   .wr_sel  (wr_sel),
        .wr_addr (wr_addr), .wr_data (wr_data),
        .feed    (feed),    .k_idx   (k_idx),
        .a_vec   (a_vec),   .b_vec   (b_vec)
    );

    input_skew #(.N(N), .DATA_W(DATA_W)) u_skew_a (
        .clk (clk), .rst_n (rst_n), .clear (clear), .en (en),
        .din (a_vec), .dout (a_west)
    );

    input_skew #(.N(N), .DATA_W(DATA_W)) u_skew_b (
        .clk (clk), .rst_n (rst_n), .clear (clear), .en (en),
        .din (b_vec), .dout (b_north)
    );

    systolic_array #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) u_array (
        .clk     (clk),    .rst_n   (rst_n),
        .clear   (clear),  .en      (en),
        .a_west  (a_west), .b_north (b_north),
        .c_flat  (c_flat)
    );

    // Output / accumulator register read-out mux
    assign rd_data = c_flat[rd_addr*ACC_W +: ACC_W];

endmodule
