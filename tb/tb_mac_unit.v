// =============================================================================
// File        : tb_mac_unit.v
// Owner       : Member 1
// Description : Directed, self-checking testbench for mac_unit.
//   T1  reset value is zero
//   T2  positive x positive
//   T3  accumulation over several cycles
//   T4  negative x positive (signed multiply)
//   T5  negative x negative
//   T6  en = 0 holds the accumulator
//   T7  clear has priority over en
//   T8  Q4.4 fractional example: 1.5 * 2.25 = 3.375
//   T9  extreme operands: (-8.0)*(-8.0) accumulated 4 times (no overflow)
//   T10 dot product of two 4-element vectors (what one PE does)
// Run  : see sim/Makefile  ->  make mac
// =============================================================================
`timescale 1ns / 1ps

module tb_mac_unit;

    localparam DATA_W = 8;
    localparam ACC_W  = 32;

    reg                     clk, rst_n, clear, en;
    reg  signed [DATA_W-1:0] a, b;
    wire signed [ACC_W-1:0]  acc;

    integer errors = 0;
    integer tests  = 0;

    mac_unit #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst_n(rst_n), .clear(clear), .en(en),
        .a(a), .b(b), .acc(acc)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    task check;
        input signed [ACC_W-1:0] expected;
        input [8*48-1:0]          name;
        begin
            tests = tests + 1;
            if (acc !== expected) begin
                errors = errors + 1;
                $display("  [FAIL] %0s : acc = %0d, expected %0d", name, acc, expected);
            end else
                $display("  [PASS] %0s : acc = %0d (%f in Q24.8)", name, acc, acc / 256.0);
        end
    endtask

    // apply one operand pair for exactly one clock edge
    task mac_step;
        input signed [DATA_W-1:0] ta, tb;
        begin
            a = ta; b = tb; en = 1'b1;
            @(posedge clk); #1;
            en = 1'b0;
        end
    endtask

    task do_clear;
        begin
            clear = 1'b1; @(posedge clk); #1; clear = 1'b0;
        end
    endtask
    // ---------------------------------------------------------------

    initial begin
        $dumpfile("tb_mac_unit.vcd");
        $dumpvars(0, tb_mac_unit);

        $display("==================================================");
        $display(" tb_mac_unit : directed MAC tests (Q4.4 operands)");
        $display("==================================================");

        rst_n = 1'b0; clear = 1'b0; en = 1'b0; a = 0; b = 0;
        #22 rst_n = 1'b1;
        @(posedge clk); #1;

        // T1
        check(0, "T1 reset");

        // T2 : 3 * 5 = 15   (raw integers)
        mac_step(8'sd3, 8'sd5);
        check(15, "T2 pos x pos (3*5)");

        // T3 : +2*4 +1*1 +7*7 -> 15+8+1+49 = 73
        mac_step(8'sd2, 8'sd4);
        mac_step(8'sd1, 8'sd1);
        mac_step(8'sd7, 8'sd7);
        check(73, "T3 accumulate");

        // T4 : -6 * 9 = -54 -> 73-54 = 19
        mac_step(-8'sd6, 8'sd9);
        check(19, "T4 neg x pos");

        // T5 : -5 * -5 = 25 -> 44
        mac_step(-8'sd5, -8'sd5);
        check(44, "T5 neg x neg");

        // T6 : en low, operands change -> hold
        a = 8'sd100; b = 8'sd100; en = 1'b0;
        repeat (3) @(posedge clk); #1;
        check(44, "T6 hold when en=0");

        // T7 : clear and en together -> clear wins
        a = 8'sd10; b = 8'sd10; en = 1'b1; clear = 1'b1;
        @(posedge clk); #1;
        en = 1'b0; clear = 1'b0;
        check(0, "T7 clear priority");

        // T8 : Q4.4  1.5 = 0x18 (24), 2.25 = 0x24 (36) -> 864 = 3.375 * 256
        mac_step(8'h18, 8'h24);
        check(864, "T8 Q4.4 1.5*2.25=3.375");

        // T9 : (-8.0)*(-8.0) = 64.0 four times = 256.0 -> 256*256 = 65536
        do_clear;
        mac_step(-8'sd128, -8'sd128);
        mac_step(-8'sd128, -8'sd128);
        mac_step(-8'sd128, -8'sd128);
        mac_step(-8'sd128, -8'sd128);
        check(65536, "T9 extreme operands x4");

        // T10 : dot([1,2,3,4],[5,6,7,8]) = 70  (back-to-back, en held high)
        do_clear;
        en = 1'b1;
        a = 8'sd1; b = 8'sd5; @(posedge clk); #1;
        a = 8'sd2; b = 8'sd6; @(posedge clk); #1;
        a = 8'sd3; b = 8'sd7; @(posedge clk); #1;
        a = 8'sd4; b = 8'sd8; @(posedge clk); #1;
        en = 1'b0;
        check(70, "T10 4-element dot product");

        $display("--------------------------------------------------");
        if (errors == 0)
            $display(" RESULT: ALL %0d MAC TESTS PASSED", tests);
        else
            $display(" RESULT: %0d / %0d MAC TESTS FAILED", errors, tests);
        $display("==================================================");
        #20 $finish;
    end

endmodule
