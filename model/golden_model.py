#!/usr/bin/env python3
"""
golden_model.py  --  Reference (golden) model for the systolic array accelerator
Owner : Member 5

What it does
  * Defines the fixed-point format used by the RTL
        operands    : signed Q4.4   (8 bit,  4 fractional bits)
        accumulator : signed Q24.8  (32 bit, 8 fractional bits)
  * Computes C = A x B exactly the way the hardware does (integer MACs on the
    raw Q4.4 codes, no rounding inside the array).
  * Generates the directed Phase-I test vectors as a single $readmemh file
    that tb/tb_systolic_top.v loads:

        vectors_count.hex       : one word, the number of tests T
        vectors.hex, per test   : N*N words of A  (row-major, 8-bit two's complement)
                                  N*N words of B  (row-major, 8-bit two's complement)
                                  N*N words of C  (row-major, 32-bit two's complement)

  * Writes a human-readable companion file (vectors_readable.txt) so the
    expected matrices can be shown in the report / video.

Pure Python 3 - no external packages needed.

Usage
    python3 golden_model.py                 # writes ../tests/vectors/*
    python3 golden_model.py --out DIR       # custom output directory
"""

import argparse
import os

N = 4            # array dimension
DATA_W = 8       # operand width
ACC_W = 32       # accumulator width
FRAC_IN = 4      # Q4.4
FRAC_ACC = 2 * FRAC_IN   # product / accumulator fractional bits (Q24.8)

# --------------------------------------------------------------------------
# Fixed-point helpers
# --------------------------------------------------------------------------
def sat(value, width):
    """Saturate a Python int to a signed 'width'-bit range."""
    lo, hi = -(1 << (width - 1)), (1 << (width - 1)) - 1
    return max(lo, min(hi, value))


def to_q44(x):
    """Real number -> raw signed Q4.4 code (round to nearest, saturate)."""
    return sat(int(round(x * (1 << FRAC_IN))), DATA_W)


def q44_to_real(code):
    return code / float(1 << FRAC_IN)


def acc_to_real(code):
    return code / float(1 << FRAC_ACC)


def to_hex(value, width):
    """Two's complement hex string of a signed int."""
    mask = (1 << width) - 1
    return format(value & mask, "0{}x".format(width // 4))


# --------------------------------------------------------------------------
# Reference matrix multiply (bit-exact with the RTL)
# --------------------------------------------------------------------------
def matmul_raw(A, B):
    """A, B are N x N lists of raw Q4.4 integer codes. Returns raw Q24.8."""
    n = len(A)
    C = [[0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            acc = 0
            for k in range(n):
                acc += A[i][k] * B[k][j]
            # The 32-bit accumulator can never overflow for N=4 and 8-bit
            # operands (max |acc| = 4 * 128 * 128 = 65536), but we still
            # check so the model flags any future parameter change.
            assert -(1 << (ACC_W - 1)) <= acc < (1 << (ACC_W - 1)), "accumulator overflow"
            C[i][j] = acc
    return C


# --------------------------------------------------------------------------
# Directed Phase-I test cases
# --------------------------------------------------------------------------
def identity(n):
    return [[1 if i == j else 0 for j in range(n)] for i in range(n)]


def directed_tests():
    tests = []

    # 1. A x I = A (integer codes)
    A = [[i * N + j + 1 for j in range(N)] for i in range(N)]
    tests.append(("integer A x identity", A, identity(N)))

    # 2. I x B = B
    B = [[(i + 1) * (j + 1) for j in range(N)] for i in range(N)]
    tests.append(("identity x integer B", identity(N), B))

    # 3. small positive integers
    A = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]
    B = [[16, 15, 14, 13], [12, 11, 10, 9], [8, 7, 6, 5], [4, 3, 2, 1]]
    tests.append(("positive integers", A, B))

    # 4. signed integers (mixed signs)
    A = [[(i - j) * 3 for j in range(N)] for i in range(N)]
    B = [[(i + 1) * (j - 2) for j in range(N)] for i in range(N)]
    tests.append(("signed integers", A, B))

    # 5. genuine Q4.4 fractional values
    Ar = [[1.5, -0.25, 2.0, 0.75],
          [-1.0, 3.25, 0.5, -2.5],
          [0.125, 0.0, -3.75, 1.0],
          [7.9375, -8.0, 0.0625, -0.5]]
    Br = [[2.25, 1.0, -0.5, 0.0],
          [0.5, -1.5, 2.0, 1.25],
          [-1.0, 0.25, 0.75, -2.0],
          [3.0, -0.125, 1.0, 0.5]]
    tests.append(("Q4.4 fractional", [[to_q44(x) for x in r] for r in Ar],
                  [[to_q44(x) for x in r] for r in Br]))

    # 6. extreme corner: all -8.0 (code -128) -> largest positive products
    A = [[-128] * N for _ in range(N)]
    tests.append(("extreme -8.0 x -8.0", A, [row[:] for row in A]))

    # 7. max positive x min negative
    A = [[127] * N for _ in range(N)]
    B = [[-128] * N for _ in range(N)]
    tests.append(("+7.9375 x -8.0", A, B))

    # 8. zero matrix
    Z = [[0] * N for _ in range(N)]
    tests.append(("zero x integer", Z, [[i - j for j in range(N)] for i in range(N)]))

    return tests


# --------------------------------------------------------------------------
# File writers
# --------------------------------------------------------------------------
def fmt_matrix(M, conv=None, width=9):
    lines = []
    for row in M:
        if conv is None:
            lines.append("  " + " ".join("{:>{w}d}".format(v, w=width) for v in row))
        else:
            lines.append("  " + " ".join("{:>{w}.4f}".format(conv(v), w=width) for v in row))
    return "\n".join(lines)


def write_vectors(tests, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    hex_path = os.path.join(out_dir, "vectors.hex")
    txt_path = os.path.join(out_dir, "vectors_readable.txt")
    cnt_path = os.path.join(out_dir, "vectors_count.hex")

    with open(cnt_path, "w") as fc:
        fc.write(to_hex(len(tests), 32) + "\n")

    with open(hex_path, "w") as fh, open(txt_path, "w") as ft:
        fh.write("// Systolic array test vectors - generated by model/golden_model.py\n")
        fh.write("// layout: per test A[16] B[16] C[16] (count is in vectors_count.hex)\n")
        ft.write("Systolic array golden-model vectors (N={}, Q4.4 in, Q24.8 out)\n\n".format(N))

        for idx, (name, A, B) in enumerate(tests):
            C = matmul_raw(A, B)
            fh.write("// test {} : {}\n".format(idx, name))
            for M, w in ((A, DATA_W), (B, DATA_W), (C, ACC_W)):
                for row in M:
                    fh.write(" ".join(to_hex(v, w) for v in row) + "\n")

            ft.write("=" * 70 + "\n")
            ft.write("test {} : {}\n".format(idx, name))
            ft.write("A (raw Q4.4 codes):\n" + fmt_matrix(A) + "\n")
            ft.write("A (real):\n" + fmt_matrix(A, q44_to_real) + "\n")
            ft.write("B (raw Q4.4 codes):\n" + fmt_matrix(B) + "\n")
            ft.write("B (real):\n" + fmt_matrix(B, q44_to_real) + "\n")
            ft.write("C expected (raw Q24.8):\n" + fmt_matrix(C) + "\n")
            ft.write("C expected (real):\n" + fmt_matrix(C, acc_to_real, 11) + "\n\n")

    return hex_path, txt_path


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.join(here, "..", "tests", "vectors")
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=default_out, help="output directory")
    args = ap.parse_args()

    tests = directed_tests()
    hex_path, txt_path = write_vectors(tests, args.out)
    print("golden_model: wrote {} directed tests".format(len(tests)))
    print("  {}".format(os.path.normpath(hex_path)))
    print("  {}".format(os.path.normpath(txt_path)))


if __name__ == "__main__":
    main()
