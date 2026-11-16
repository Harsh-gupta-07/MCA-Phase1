// =============================================================================
// File        : systolic_controller.v
// Project     : Systolic Array Matrix Multiplication Accelerator (CSA-222)
// Owner       : Member 4
// Description : Finite State Machine that sequences one N x N matrix product.
//
//   State transition (Moore outputs in brackets)
//
//      +------+  start   +-------+        +------+  k==N-1  +-------+
//  --> | IDLE | -------> | CLEAR | -----> | FEED | -------> | DRAIN |
//      +------+          +-------+        +------+          +-------+
//         ^              [clear]          [en, feed]        [en] |
//         |                                k++              cnt++|
//         |                +------+   cnt == DRAIN_CYC-1         |
//         +----------------| DONE | <----------------------------+
//                          +------+
//                          [done pulse]
//
//   IDLE  : wait for start
//   CLEAR : zero all accumulators, forwarding and skew registers (1 cycle)
//   FEED  : stream step k = 0..N-1 from the input buffers into the skew logic
//   DRAIN : inject zeros for 2N-2 cycles so the last operands reach PE(N-1,N-1)
//   DONE  : one-cycle done pulse; results are stable in the PE accumulators
//
//   Compute latency (FEED + DRAIN) = N + (2N-2) = 3N-2 cycles.
// =============================================================================
`timescale 1ns / 1ps

module systolic_controller #(
    parameter N  = 4,
    parameter KW = (N > 1) ? $clog2(N) : 1
) (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,
    output reg           clear,
    output reg           en,
    output reg           feed,
    output reg  [KW-1:0] k_idx,
    output reg           busy,
    output reg           done
);

    localparam [2:0] S_IDLE  = 3'd0,
                     S_CLEAR = 3'd1,
                     S_FEED  = 3'd2,
                     S_DRAIN = 3'd3,
                     S_DONE  = 3'd4;

    localparam integer DRAIN_CYC = (N > 1) ? (2*N - 2) : 1;
    localparam integer CW        = $clog2(DRAIN_CYC + 1);

    reg [2:0]    state, next_state;
    reg [CW-1:0] drain_cnt;

    // ---------------- state register + counters ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            k_idx     <= {KW{1'b0}};
            drain_cnt <= {CW{1'b0}};
        end else begin
            state <= next_state;
            case (state)
                S_CLEAR: k_idx     <= {KW{1'b0}};
                S_FEED : begin
                    k_idx     <= k_idx + 1'b1;
                    drain_cnt <= {CW{1'b0}};
                end
                S_DRAIN: drain_cnt <= drain_cnt + 1'b1;
                default: ;
            endcase
        end
    end

    // ---------------- next-state logic ----------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE : if (start)                         next_state = S_CLEAR;
            S_CLEAR:                                    next_state = S_FEED;
            S_FEED : if (k_idx == N-1)                  next_state = S_DRAIN;
            S_DRAIN: if (drain_cnt == DRAIN_CYC-1)      next_state = S_DONE;
            S_DONE :                                    next_state = S_IDLE;
            default:                                    next_state = S_IDLE;
        endcase
    end

    // ---------------- Moore output logic ----------------
    always @(*) begin
        clear = 1'b0;
        en    = 1'b0;
        feed  = 1'b0;
        busy  = 1'b1;
        done  = 1'b0;
        case (state)
            S_IDLE : busy  = 1'b0;
            S_CLEAR: clear = 1'b1;
            S_FEED : begin en = 1'b1; feed = 1'b1; end
            S_DRAIN: en    = 1'b1;
            S_DONE : begin done = 1'b1; busy = 1'b0; end
            default: busy  = 1'b0;
        endcase
    end

endmodule
