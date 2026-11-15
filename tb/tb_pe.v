// =============================================================================
// File        : tb_pe.v
// Owner       : Member 2
// Description : Directed, self-checking testbench for the Processing Element.
//   T1 a_in / b_in are forwarded to a_out / b_out after exactly one cycle
//   T2 the PE accumulates a_in*b_in every enabled cycle
//   T3 en = 0 freezes both the forwarding registers and the accumulator
//   T4 clear zeroes the accumulator and the forwarding registers
//   T5 a stream of 4 operand pairs produces the expected dot product while
//      the same stream appears on a_out / b_out delayed by one cycle
// Run  : see sim/Makefile  ->  make pe
// =============================================================================
`timescale 1ns / 1ps

module tb_pe;

    localparam DATA_W = 8;
    localparam ACC_W  = 32;

    reg                      clk, rst_n, clear, en;
    reg  signed [DATA_W-1:0] a_in, b_in;
    wire signed [DATA_W-1:0] a_out, b_out;
    wire signed [ACC_W-1:0]  acc_out;

    integer errors = 0;
    integer tests  = 0;
    integer k;

    reg signed [DATA_W-1:0] va [0:3];
    reg signed [DATA_W-1:0] vb [0:3];

    pe #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst_n(rst_n), .clear(clear), .en(en),
        .a_in(a_in), .b_in(b_in),
        .a_out(a_out), .b_out(b_out), .acc_out(acc_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task check_val;
        input signed [ACC_W-1:0] got;
        input signed [ACC_W-1:0] expected;
        input [8*48-1:0]          name;
        begin
            tests = tests + 1;
            if (got !== expected) begin
                errors = errors + 1;
                $display("  [FAIL] %0s : got %0d, expected %0d", name, got, expected);
            end else
                $display("  [PASS] %0s : %0d", name, got);
        end
    endtask

    initial begin
        $dumpfile("tb_pe.vcd");
        $dumpvars(0, tb_pe);

        $display("==================================================");
        $display(" tb_pe : Processing Element directed tests");
        $display("==================================================");

        rst_n = 0; clear = 0; en = 0; a_in = 0; b_in = 0;
        #22 rst_n = 1;
        @(posedge clk); #1;

        // ---- T1 + T2 : forward and accumulate in one step ----
        a_in = 8'sd3; b_in = -8'sd4; en = 1;
        @(posedge clk); #1;
        check_val(a_out,   3,   "T1 a_out = a_in (1-cycle delay)");
        check_val(b_out,  -4,   "T1 b_out = b_in (1-cycle delay)");
        check_val(acc_out, -12, "T2 acc = 3*(-4)");

        // ---- T3 : freeze ----
        en = 0; a_in = 8'sd99; b_in = 8'sd99;
        repeat (2) @(posedge clk); #1;
        check_val(a_out,    3,  "T3 a_out frozen");
        check_val(acc_out, -12, "T3 acc frozen");

        // ---- T4 : clear ----
        clear = 1; @(posedge clk); #1; clear = 0;
        check_val(acc_out, 0, "T4 acc cleared");
        check_val(a_out,   0, "T4 a_out cleared");
        check_val(b_out,   0, "T4 b_out cleared");

        // ---- T5 : stream of 4 pairs, dot([2,-3,5,1],[4,6,-2,7]) ----
        //       = 8 - 18 - 10 + 7 = -13
        va[0] =  8'sd2; vb[0] =  8'sd4;
        va[1] = -8'sd3; vb[1] =  8'sd6;
        va[2] =  8'sd5; vb[2] = -8'sd2;
        va[3] =  8'sd1; vb[3] =  8'sd7;
        en = 1;
        for (k = 0; k < 4; k = k + 1) begin
            a_in = va[k]; b_in = vb[k];
            @(posedge clk); #1;
            // the value just sampled must now be on the outputs
            check_val(a_out, va[k], "T5 a stream forwarded");
            check_val(b_out, vb[k], "T5 b stream forwarded");
        end
        en = 0; a_in = 0; b_in = 0;
        check_val(acc_out, -13, "T5 streamed dot product");

        $display("--------------------------------------------------");
        if (errors == 0)
            $display(" RESULT: ALL %0d PE TESTS PASSED", tests);
        else
            $display(" RESULT: %0d / %0d PE TESTS FAILED", errors, tests);
        $display("==================================================");
        #20 $finish;
    end

endmodule
