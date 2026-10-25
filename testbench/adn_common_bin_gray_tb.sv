/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|  
| TC_001    | 2026-09-06 | Foez Ahmed      | Test case description goes here                       |
| TC_002    | 2026-09-06 | Foez Ahmed      | Test case description goes here                       |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-06 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-09-06 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_bin_gray_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int WIDTH = 16;
  localparam int MIN_VAL = '0;
  localparam int MAX_VAL = 2 ** WIDTH - 1;
  localparam int ONE_THIRD = (2 ** WIDTH) / 3;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  covergroup cg_bin_gray with function sample (input logic [WIDTH-1:0] num_in);
    num_in_cp: coverpoint num_in {
      bins zeros = {MIN_VAL};
      bins lower = {[(MIN_VAL + 1) : (1 * ONE_THIRD)]};
      bins mid = {[(1 * ONE_THIRD + 1) : (2 * ONE_THIRD)]};
      bins high = {[(2 * ONE_THIRD + 1) : (MAX_VAL - 1)]};
      bins ones = {MAX_VAL};
    }
  endgroup

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit clk;

  logic [WIDTH-1:0] bin_in;
  logic [WIDTH-1:0] gray_out;
  logic [WIDTH-1:0] ref_gray_out;

  logic [WIDTH-1:0] gray_in;
  logic [WIDTH-1:0] bin_out;
  logic [WIDTH-1:0] ref_bin_out;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function automatic logic [WIDTH-1:0] bin_to_gray(input logic [WIDTH-1:0] bin);
    return ((bin >> 1) ^ bin);
  endfunction

  function automatic logic [WIDTH-1:0] gray_to_bin(input logic [WIDTH-1:0] gray);
    logic [WIDTH-1:0] bin;
    bin[WIDTH-1] = gray[WIDTH-1];
    for (int i = WIDTH-1 - 1; i >= 0; i--) begin
      bin[i] = bin[i+1] ^ gray[i];
    end
    return bin;
  endfunction

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb ref_gray_out = bin_to_gray(bin_in);
  always_comb ref_bin_out  = gray_to_bin(gray_in);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  cg_bin_gray bin_in_cov = new();
  cg_bin_gray gray_in_cov = new();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_bin_to_gray #(
      .WIDTH(WIDTH)
  ) dut_0 (
      .bin_i (bin_in),
      .gray_o(gray_out)
  );

  adn_common_gray_to_bin #(
      .WIDTH(WIDTH)
  ) dut_1 (
      .gray_i(gray_in),
      .bin_o (bin_out)
  );

  `define SMARTER_RANDOM_DATA_GENERATION(__PORT__)                                                 \
                                                                                                   \
    // SMARTER RANDOM DATA GENERATION                                                              \
    begin                                                                                          \
      automatic int weight_zeros = 20;                                                             \
      automatic int weight_lower = 20;                                                             \
      automatic int weight_mid = 20;                                                               \
      automatic int weight_high = 20;                                                              \
      automatic int weight_ones = 20;                                                              \
      forever begin                                                                                \
        @(posedge clk);                                                                            \
        randcase                                                                                   \
                                                                                                   \
          weight_zeros: begin                                                                      \
            ``__PORT__`` <= MIN_VAL;                                                               \
            weight_zeros--;                                                                        \
          end                                                                                      \
                                                                                                   \
          weight_lower: begin                                                                      \
            ``__PORT__`` <= $urandom_range((MIN_VAL + 1), (1 * ONE_THIRD));                        \
            weight_lower--;                                                                        \
          end                                                                                      \
                                                                                                   \
          weight_mid: begin                                                                        \
            ``__PORT__`` <= $urandom_range((1 * ONE_THIRD + 1), (2 * ONE_THIRD));                  \
            weight_mid--;                                                                          \
          end                                                                                      \
                                                                                                   \
          weight_high: begin                                                                       \
            ``__PORT__`` <= $urandom_range((2 * ONE_THIRD + 1), (MAX_VAL - 1));                    \
            weight_high--;                                                                         \
          end                                                                                      \
                                                                                                   \
          weight_ones: begin                                                                       \
            ``__PORT__`` <= MAX_VAL;                                                               \
            weight_ones--;                                                                         \
          end                                                                                      \
                                                                                                   \
        endcase                                                                                    \
                                                                                                   \
        if (weight_zeros + weight_lower + weight_mid + weight_high + weight_ones == 0) begin       \
          weight_zeros = 20;                                                                       \
          weight_lower = 20;                                                                       \
          weight_mid   = 20;                                                                       \
          weight_high  = 20;                                                                       \
          weight_ones  = 20;                                                                       \
        end                                                                                        \
      end                                                                                          \
    end                                                                                            \


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial

    clk    <= '0;
    bin_in <= '0;

    #5ns;

    fork

      // CLOCK GENERATION
      forever begin
        #5ns;
        clk <= ~clk;
      end

      // BIN INPUT GENERATION
      `SMARTER_RANDOM_DATA_GENERATION(bin_in)

      // GRAY INPUT GENERATION
      `SMARTER_RANDOM_DATA_GENERATION(gray_in)

      // SCOREBOARDING
      forever begin
        @(posedge clk);
        if (gray_out !== ref_gray_out) begin
          $error("Mismatch detected: bin_in=%0h, gray_out=%0h, ref_gray_out=%0h", bin_in, gray_out,
                 ref_gray_out);
          note_case(0);
        end else begin
          note_case(1);
        end
        if (bin_out !== ref_bin_out) begin
          $error("Mismatch detected: gray_in=%0h, bin_out=%0h, ref_bin_out=%0h", gray_in, bin_out,
                 ref_bin_out);
          note_case(0);
        end else begin
          note_case(1);
        end
      end

      // COVERAGE
      forever begin
        @(posedge clk);
        bin_in_cov.sample(bin_in);
        gray_in_cov.sample(gray_in);
      end

    join_none

    while (bin_in_cov.get_inst_coverage() < 100 || gray_in_cov.get_inst_coverage() < 100) begin
      #10ns;
      $display("Current coverage - bin_in: %0.2f, gray_in: %0.2f", bin_in_cov.get_inst_coverage(),
               gray_in_cov.get_inst_coverage());
    end

    $finish;

  end

  `undef SMARTER_RANDOM_DATA_GENERATION

endmodule
