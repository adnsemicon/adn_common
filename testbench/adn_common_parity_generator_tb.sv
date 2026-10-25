/*

| TEST CASE | DATE       | AUTHOR                     | DESCRIPTION                                      |
|-----------|------------|----------------------------|--------------------------------------------------|
| TC_001    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Even parity calculation                          |
| TC_002    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Odd parity calculation                           |
| TC_003    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Boundary num_bits values                         |
| TC_004    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Different number of bits                         |
| TC_005    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Corner data patterns                             |
| TC_006    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Upper bits must be ignored                       |
| TC_007    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Randomized parity stress test                    |
| TC_008    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Zero Num bits test                               |
| TC_ALL    | 2026-08-19 | Md Sakhawat Hossain Sabbir | Run all test cases                               |

| REVISION | DATE       | AUTHOR                     | DESCRIPTION       |
|----------|------------|----------------------------|-------------------|
| 0.1      | 2026-08-19 | Md Sakhawat Hossain Sabbir | Initial version   |
| 1.0      | 2026-08-19 | Md Sakhawat Hossain Sabbir | Stable release    |

Author : Md Sakhawat Hossain Sabbir (sabbirone939@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_parity_generator_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  parameter int DATA_WIDTH = 8;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [$clog2(DATA_WIDTH+1)-1:0] num_bits_i;
  logic [          DATA_WIDTH-1:0] data_i;
  logic                            parity_type_i;
  logic                            parity_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_parity_generator #(
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .num_bits_i   (num_bits_i),
      .data_i       (data_i),
      .parity_type_i(parity_type_i),
      .parity_o     (parity_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // REFERENCE MODEL
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function automatic logic calculate_expected_parity(input logic [DATA_WIDTH-1:0] data,
                                                     input int num_bits, input logic parity_type);
    logic parity;

    parity = 1'b0;
    for (int i = 0; i < num_bits; i++) parity ^= data[i];

    // Even parity = XOR result, Odd parity = inverted XOR result
    calculate_expected_parity = parity_type ? ~parity : parity;
  endfunction

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // TC_001: EVEN PARITY
  task automatic even_parity_test();
    logic expected_data;
    bit   test_pass;

    $display(" EVEN PARITY TEST ");
    test_pass = 1'b1;
    num_bits_i = DATA_WIDTH;
    parity_type_i = 1'b0;

    // All zero
    data_i = '0;
    #1;
    expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);
    if (parity_o !== expected_data) begin
      test_pass = 1'b0;
      if (debug)
        $display("FAIL EVEN ZERO: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o);
    end

    // All one
    if (test_pass) begin
      data_i = '1;
      #1;
      expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);
      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display("FAIL EVEN ONE: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o);
      end
    end

    // Random data
    if (test_pass) begin
      repeat (10) begin
        data_i = $urandom();
        #1;
        expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);
        if (parity_o !== expected_data) begin
          test_pass = 1'b0;
          if (debug)
            $display(
                "FAIL EVEN RANDOM: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o
            );
          break;
        end
      end
    end

    note_case(test_pass);
  endtask

  // TC_002: ODD PARITY
  task automatic odd_parity_test();
    logic expected_data;
    bit   test_pass;

    $display(" ODD PARITY TEST ");
    test_pass = 1'b1;
    num_bits_i = DATA_WIDTH;
    parity_type_i = 1'b1;

    // All zero
    data_i = '0;
    #1;
    expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);
    if (parity_o !== expected_data) begin
      test_pass = 1'b0;
      if (debug)
        $display("FAIL ODD ZERO: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o);
    end

    // All one
    if (test_pass) begin
      data_i = '1;
      #1;
      expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);
      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display("FAIL ODD ONE: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o);
      end
    end

    // Random data
    if (test_pass) begin
      repeat (10) begin
        data_i = $urandom();
        #1;
        expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);
        if (parity_o !== expected_data) begin
          test_pass = 1'b0;
          if (debug)
            $display(
                "FAIL ODD RANDOM: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o
            );
          break;
        end
      end
    end

    note_case(test_pass);
  endtask

  // TC_003: BOUNDARY NUM_BITS
  task automatic boundary_test();
    logic expected_data;
    bit   test_pass;
    int   boundary_bits [2];

    $display(" BOUNDARY TEST ");
    test_pass = 1'b1;
    boundary_bits[0] = 1;
    boundary_bits[1] = DATA_WIDTH;
    data_i = $urandom();

    for (int i = 0; i < 2; i++) begin
      num_bits_i = boundary_bits[i];
      parity_type_i = $urandom_range(0, 1);
      #1;
      expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);

      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display(
              "FAIL BOUNDARY: NUM_BITS=%0d DATA=%b TYPE=%0d EXPECTED=%0b GOT=%0b",
              num_bits_i,
              data_i,
              parity_type_i,
              expected_data,
              parity_o
          );
        break;
      end
    end

    note_case(test_pass);
  endtask

  // TC_004: DIFFERENT NUM_BITS
  task automatic num_bits_test();
    logic expected_data;
    bit   test_pass;

    $display(" NUM_BITS TEST ");
    test_pass = 1'b1;
    data_i = $urandom();

    for (int i = 1; i <= DATA_WIDTH; i++) begin
      num_bits_i = i;
      parity_type_i = $urandom_range(0, 1);
      #1;
      expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);

      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display(
              "FAIL NUM_BITS: NUM_BITS=%0d DATA=%b TYPE=%0d EXPECTED=%0b GOT=%0b",
              num_bits_i,
              data_i,
              parity_type_i,
              expected_data,
              parity_o
          );
        break;
      end
    end

    note_case(test_pass);
  endtask

  // TC_005: CORNER DATA PATTERNS
  task automatic corner_test();
    logic [DATA_WIDTH-1:0] patterns      [4];
    logic                  expected_data;
    bit                    test_pass;

    $display(" CORNER TEST ");
    test_pass   = 1'b1;
    patterns[0] = '0;
    patterns[1] = '1;
    patterns[2] = 'h55;
    patterns[3] = 'hAA;
    num_bits_i  = DATA_WIDTH;

    for (int i = 0; i < 4; i++) begin
      data_i = patterns[i];
      parity_type_i = $urandom_range(0, 1);
      #1;
      expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);

      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display(
              "FAIL CORNER: DATA=%b TYPE=%0d EXPECTED=%0b GOT=%0b",
              data_i,
              parity_type_i,
              expected_data,
              parity_o
          );
        break;
      end
    end

    note_case(test_pass);
  endtask

  // TC_006: UPPER BITS MUST BE IGNORED
  task automatic upper_bits_ignore_test();
    logic [DATA_WIDTH-1:0] base_data;
    logic                  expected_data;
    bit                    test_pass;
    int                    selected_bits;

    $display(" UPPER BITS TEST ");
    test_pass = 1'b1;
    selected_bits = DATA_WIDTH / 2;
    num_bits_i = selected_bits;
    parity_type_i = $urandom_range(0, 1);

    base_data = '0;
    for (int i = 0; i < selected_bits; i++) base_data[i] = $urandom_range(0, 1);

    expected_data = calculate_expected_parity(base_data, num_bits_i, parity_type_i);

    repeat (10) begin
      data_i = base_data;
      for (int i = selected_bits; i < DATA_WIDTH; i++) data_i[i] = $urandom_range(0, 1);

      #1;
      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display(
              "FAIL UPPER BITS: DATA=%b NUM_BITS=%0d EXPECTED=%0b GOT=%0b",
              data_i,
              num_bits_i,
              expected_data,
              parity_o
          );
        break;
      end
    end

    note_case(test_pass);
  endtask

  // TC_007: RANDOMIZED STRESS TEST
  task automatic random_test();
    logic [DATA_WIDTH-1:0] random_data;
    logic                  random_type;
    logic                  expected_data;
    int                    random_bits;
    int                    iterations;
    bit                    test_pass;

    $display(" RANDOM TEST ");
    test_pass  = 1'b1;
    iterations = (test_count > 0) ? test_count : 100;

    repeat (iterations) begin
      random_data = $urandom();
      random_bits = $urandom_range(1, DATA_WIDTH);
      random_type = $urandom_range(0, 1);

      data_i = random_data;
      num_bits_i = random_bits;
      parity_type_i = random_type;
      #1;

      expected_data = calculate_expected_parity(random_data, random_bits, random_type);

      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display(
              "FAIL RANDOM: DATA=%b NUM_BITS=%0d TYPE=%0d EXPECTED=%0b GOT=%0b",
              random_data,
              random_bits,
              random_type,
              expected_data,
              parity_o
          );
        break;
      end
    end

    note_case(test_pass);
  endtask

  // TC_008: ZERO NUM_BITS
  task automatic zero_numbits_test();
    logic expected_data;
    bit   test_pass;

    $display(" ZERO NUM_BITS TEST ");
    test_pass = 1'b1;
    num_bits_i = 0;

    // EVEN PARITY
    data_i = $urandom();
    parity_type_i = 1'b0;
    #1;
    expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);

    if (parity_o !== expected_data) begin
      test_pass = 1'b0;
      if (debug)
        $display(
            "FAIL ZERO BITS EVEN: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o
        );
    end

    // ODD PARITY
    if (test_pass) begin
      data_i = $urandom();
      parity_type_i = 1'b1;
      #1;
      expected_data = calculate_expected_parity(data_i, num_bits_i, parity_type_i);

      if (parity_o !== expected_data) begin
        test_pass = 1'b0;
        if (debug)
          $display(
              "FAIL ZERO BITS ODD: DATA=%b EXPECTED=%0b GOT=%0b", data_i, expected_data, parity_o
          );
      end
    end

    note_case(test_pass);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    case (test_name)
      "TC_001": even_parity_test();
      "TC_002": odd_parity_test();
      "TC_003": boundary_test();
      "TC_004": num_bits_test();
      "TC_005": corner_test();
      "TC_006": upper_bits_ignore_test();
      "TC_007": random_test();
      "TC_008": zero_numbits_test();

      "TC_ALL": begin
        even_parity_test();
        odd_parity_test();
        boundary_test();
        num_bits_test();
        corner_test();
        upper_bits_ignore_test();
        random_test();
        zero_numbits_test();
      end

      default: $fatal(1, "\033[1;31mUNKNOWN TEST NAME: %s\033[0m", test_name);

    endcase

    $finish;
  end

endmodule
