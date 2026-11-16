// =============================================================================
// File        : tb_systolic_array.v
// Owner       : Member 3
// Description : Array-level testbench (no controller, no buffers).
//   The testbench itself plays the role of the controller: it presents
//   column k of A and row k of B for k = 0..N-1, the input_skew modules
//   stagger them into a diagonal wavefront, and after 2N-2 drain cycles the
//   PE accumulators are compared against C = A x B computed in the testbench.
//
//   Test 1 : A = small positive integers, B = identity   -> C = A
//   Test 2 : A, B = signed integers                       -> C = A x B
// Run  : see sim/Makefile  ->  make array
// =============================================================================
`timescale 1ns / 1ps

module tb_systolic_array;

    localparam N      = 4;
    localparam DATA_W = 8;
    localparam ACC_W  = 32;

    reg clk, rst_n, clear, en;
    reg  [N*DATA_W-1:0]  a_vec, b_vec;
    wire [N*DATA_W-1:0]  a_west, b_north;
    wire [N*N*ACC_W-1:0] c_flat;

    reg signed [DATA_W-1:0] A   [0:N*N-1];   // row-major
    reg signed [DATA_W-1:0] B   [0:N*N-1];
    reg signed [ACC_W-1:0]  REF [0:N*N-1];

    integer i, j, k, cyc;
    integer errors = 0;

    input_skew #(.N(N), .DATA_W(DATA_W)) u_skew_a (
        .clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .din(a_vec), .dout(a_west));
    input_skew #(.N(N), .DATA_W(DATA_W)) u_skew_b (
        .clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .din(b_vec), .dout(b_north));
    systolic_array #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst_n(rst_n), .clear(clear), .en(en),
        .a_west(a_west), .b_north(b_north), .c_flat(c_flat));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Reference model (behavioural triple loop)
    task compute_reference;
        begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    REF[i*N+j] = 0;
                    for (k = 0; k < N; k = k + 1)
                        REF[i*N+j] = REF[i*N+j] + A[i*N+k] * B[k*N+j];
                end
        end
    endtask

    // Stream A and B through the array, then compare
    task run_and_check;
        input [8*32-1:0] name;
        reg signed [ACC_W-1:0] got;
        integer local_err;
        begin
            local_err = 0;
            compute_reference;
            // clear pipeline
            clear = 1; en = 0; @(posedge clk); #1; clear = 0;
            // feed N steps + drain 2N-2 cycles
            en = 1;
            for (cyc = 0; cyc < 3*N-2; cyc = cyc + 1) begin
                for (i = 0; i < N; i = i + 1) begin
                    a_vec[i*DATA_W +: DATA_W] = (cyc < N) ? A[i*N + cyc] : 0;  // A[i][k]
                    b_vec[i*DATA_W +: DATA_W] = (cyc < N) ? B[cyc*N + i] : 0;  // B[k][i]
                end
                @(posedge clk); #1;
            end
            en = 0; a_vec = 0; b_vec = 0;
            // compare
            $display("  %0s", name);
            for (i = 0; i < N; i = i + 1) begin
                $write("    C row %0d :", i);
                for (j = 0; j < N; j = j + 1) begin
                    got = c_flat[(i*N+j)*ACC_W +: ACC_W];
                    $write(" %6d", got);
                    if (got !== REF[i*N+j]) local_err = local_err + 1;
                end
                $write("\n");
            end
            if (local_err == 0) $display("    [PASS] matches reference");
            else                $display("    [FAIL] %0d mismatching elements", local_err);
            errors = errors + local_err;
        end
    endtask

    initial begin
        $dumpfile("tb_systolic_array.vcd");
        $dumpvars(0, tb_systolic_array);

        $display("==================================================");
        $display(" tb_systolic_array : %0dx%0d array, skewed streaming", N, N);
        $display("==================================================");

        rst_n = 0; clear = 0; en = 0; a_vec = 0; b_vec = 0;
        #22 rst_n = 1;
        @(posedge clk); #1;

        // ---- Test 1 : A x I = A ----
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                A[i*N+j] = i*N + j + 1;          // 1..16
                B[i*N+j] = (i == j) ? 1 : 0;     // identity
            end
        run_and_check("Test 1 : A x I");

        // ---- Test 2 : signed values ----
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                A[i*N+j] = (i - j) * 3;          // -9 .. 9
                B[i*N+j] = (i + 1) * (j - 2);    // -8 .. 4
            end
        run_and_check("Test 2 : signed A x B");

        $display("--------------------------------------------------");
        if (errors == 0) $display(" RESULT: ARRAY TESTS PASSED");
        else             $display(" RESULT: ARRAY TESTS FAILED (%0d errors)", errors);
        $display("==================================================");
        #20 $finish;
    end

endmodule
