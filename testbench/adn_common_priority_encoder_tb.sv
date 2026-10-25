/*

| TEST CASE | TEST NAME                  | DATE       | AUTHOR                       | DESCRIPTION                                                                 |
|-----------|----------------------------|------------|------------------------------|-----------------------------------------------------------------------------|
| TC_001    | `no_input`                 | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies priority encoder behavior when no input is asserted.               |
| TC_002    | `single_input`             | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies priority encoder behavior when exactly one input is asserted.      |
| TC_003    | `two_adjacent_inputs`      | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies low- and high-index priority when two adjacent inputs are active.  |
| TC_004    | `two_non_adjacent_inputs`  | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies priority selection when two non-adjacent inputs are active.        |
| TC_005    | `three_inputs`             | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies priority selection when three inputs are simultaneously active.    |
| TC_006    | `all_inputs`               | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies priority selection when all inputs are simultaneously active.      |
| TC_007    | `lowest_input_absent`      | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies priority selection when the lowest-index input is not asserted.    |
| TC_008    | `highest_input_absent`     | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies priority selection when the highest-index input is not asserted.   |
| TC_009    | `input_transition`         | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies correct priority encoder operation across input transitions.       |
| TC_010    | `exhaustive`               | 2026-08-18 | Md. Sakib Hasan Shawon       | Verifies all possible 4-bit input patterns and expected priority outputs.   |
| --------- | `all`                      | 2026-08-18 | Md. Sakib Hasan Shawon       | Runs the complete directed priority encoder test suite.                     |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-18 | Md. Sakib Hasan Shawon | Initial version                                 |
| 1.0      | 2026-08-19 | Md. Sakib Hasan Shawon | Stable release                                  |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_priority_encoder_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Number of input wires connected to the priority encoder.
  localparam int NUM_WIRE = 4;

  // Width required to represent an input index from 0 to NUM_WIRE-1.
  localparam int ADDR_WIDTH = $clog2(NUM_WIRE);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Priority encoder input.
  logic [  NUM_WIRE-1:0] d_i;

  // Output from the low-index-priority DUT.
  logic [ADDR_WIDTH-1:0] addr_low;
  logic                  valid_low;

  // Output from the high-index-priority DUT.
  logic [ADDR_WIDTH-1:0] addr_high;
  logic                  valid_high;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT [LOW INDEX PRIORITY]
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_priority_encoder #(
      .NUM_WIRE(NUM_WIRE),
      .HIGH_INDEX_PRIORITY(1'b0)
  ) dut_low_priority (
      .d_i(d_i),
      .addr_o(addr_low),
      .addr_valid_o(valid_low)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT [HIGH INDEX PRIORITY]
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_priority_encoder #(
      .NUM_WIRE(NUM_WIRE),
      .HIGH_INDEX_PRIORITY(1'b1)
  ) dut_high_priority (
      .d_i(d_i),
      .addr_o(addr_high),
      .addr_valid_o(valid_high)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CHECK RESULT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Compare the outputs of both DUT configurations against the expected values.
  task automatic check_result(
      input logic expected_low_valid, input logic [ADDR_WIDTH-1:0] expected_low_addr,
      input logic expected_high_valid, input logic [ADDR_WIDTH-1:0] expected_high_addr,
      input string case_name);

    logic result;

    // Compare both low-priority and high-priority DUT outputs.
    result = (
    (valid_low  === expected_low_valid)  &&
    (addr_low   === expected_low_addr)   &&
    (valid_high === expected_high_valid) &&
    (addr_high  === expected_high_addr)
  );

    // Print detailed PASS information.
    if (result) begin
      $display("PASS: %-30s d_i=%b | LOW: valid=%b addr=%0d | HIGH: valid=%b addr=%0d", case_name,
               d_i, valid_low, addr_low, valid_high, addr_high);
    end  // Print detailed FAIL information including expected values.
    else begin
      $display(
          "FAIL: %-30s d_i=%b | LOW: valid=%b addr=%0d (exp valid=%b addr=%0d) | HIGH: valid=%b addr=%0d (exp valid=%b addr=%0d)",
          case_name, d_i, valid_low, addr_low, expected_low_valid, expected_low_addr, valid_high,
          addr_high, expected_high_valid, expected_high_addr);
    end

    // Update the global pass/fail counter.
    note_case(result);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 1
  // NO INPUT
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic test_1_no_input();

    $display("\n========== TEST 1: NO INPUT ==========");

    // No input is asserted.
    d_i = 4'b0000;
    #1;

    // Both DUTs must report invalid and address 0.
    check_result(1'b0, 2'd0, 1'b0, 2'd0, "TEST 1: NO INPUT");
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 2
  // SINGLE INPUT
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic test_2_single_input();

    $display("\n========== TEST 2: SINGLE INPUT ==========");

    // Only input 0 is asserted.
    d_i = 4'b0001;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd0, "TEST 2.1: INPUT 0");

    // Only input 1 is asserted.
    d_i = 4'b0010;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd1, "TEST 2.2: INPUT 1");

    // Only input 2 is asserted.
    d_i = 4'b0100;
    #1;
    check_result(1'b1, 2'd2, 1'b1, 2'd2, "TEST 2.3: INPUT 2");

    // Only input 3 is asserted.
    d_i = 4'b1000;
    #1;
    check_result(1'b1, 2'd3, 1'b1, 2'd3, "TEST 2.4: INPUT 3");
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 3
  // TWO ADJACENT INPUTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_3_two_adjacent_inputs();

    $display("\n========== TEST 3: TWO ADJACENT INPUTS ==========");

    // Inputs 0 and 1 are asserted.
    d_i = 4'b0011;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd1, "TEST 3.1: INPUT 0,1");

    // Inputs 1 and 2 are asserted.
    d_i = 4'b0110;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd2, "TEST 3.2: INPUT 1,2");

    // Inputs 2 and 3 are asserted.
    d_i = 4'b1100;
    #1;
    check_result(1'b1, 2'd2, 1'b1, 2'd3, "TEST 3.3: INPUT 2,3");
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 4
  // TWO NON-ADJACENT INPUTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_4_two_non_adjacent_inputs();

    $display("\n========== TEST 4: TWO NON-ADJACENT INPUTS ==========");

    // Inputs 0 and 2 are asserted.
    d_i = 4'b0101;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd2, "TEST 4.1: INPUT 0,2");

    // Inputs 0 and 3 are asserted.
    d_i = 4'b1001;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 4.2: INPUT 0,3");

    // Inputs 1 and 3 are asserted.
    d_i = 4'b1010;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd3, "TEST 4.3: INPUT 1,3");
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 5
  // THREE INPUTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_5_three_inputs();

    $display("\n========== TEST 5: THREE INPUTS ==========");

    // Inputs 0, 1 and 2 are asserted.
    d_i = 4'b0111;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd2, "TEST 5.1: INPUT 0,1,2");

    // Inputs 0, 1 and 3 are asserted.
    d_i = 4'b1011;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 5.2: INPUT 0,1,3");

    // Inputs 0, 2 and 3 are asserted.
    d_i = 4'b1101;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 5.3: INPUT 0,2,3");

    // Inputs 1, 2 and 3 are asserted.
    d_i = 4'b1110;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd3, "TEST 5.4: INPUT 1,2,3");
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 6
  // ALL INPUTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_6_all_inputs();

    $display("\n========== TEST 6: ALL INPUTS ==========");

    // All inputs are asserted.
    d_i = 4'b1111;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 6: ALL INPUTS");
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 7
  // LOWEST INPUT ABSENT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_7_lowest_input_absent();

    $display("\n========== TEST 7: LOWEST INPUT ABSENT ==========");

    // Input 0 is absent; inputs 1, 2 and 3 are asserted.
    d_i = 4'b1110;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd3, "TEST 7: INPUT 0 ABSENT");
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 8
  // HIGHEST INPUT ABSENT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_8_highest_input_absent();

    $display("\n========== TEST 8: HIGHEST INPUT ABSENT ==========");

    // Input 3 is absent; inputs 0, 1 and 2 are asserted.
    d_i = 4'b0111;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd2, "TEST 8: INPUT 3 ABSENT");
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 9
  // INPUT TRANSITION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_9_input_transition();

    $display("\n========== TEST 9: INPUT TRANSITION ==========");

    // Start with no input asserted.
    d_i = 4'b0000;
    #1;
    check_result(1'b0, 2'd0, 1'b0, 2'd0, "TEST 9.1: NO INPUT");

    // Transition to input 0.
    d_i = 4'b0001;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd0, "TEST 9.2: INPUT 0");

    // Transition to inputs 0 and 3.
    d_i = 4'b1001;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 9.3: INPUT 0,3");

    // Transition to input 2.
    d_i = 4'b0100;
    #1;
    check_result(1'b1, 2'd2, 1'b1, 2'd2, "TEST 9.4: INPUT 2");

    // Return to no input.
    d_i = 4'b0000;
    #1;
    check_result(1'b0, 2'd0, 1'b0, 2'd0, "TEST 9.5: NO INPUT");
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 10
  // EXHAUSTIVE INPUT PATTERNS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_10_exhaustive();

    $display("\n========== TEST 10: EXHAUSTIVE INPUT PATTERNS ==========");

    // 0000: No inputs asserted.
    d_i = 4'b0000;
    #1;
    check_result(1'b0, 2'd0, 1'b0, 2'd0, "TEST 10.1: 0000");

    // 0001: Input 0 asserted.
    d_i = 4'b0001;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd0, "TEST 10.2: 0001");

    // 0010: Input 1 asserted.
    d_i = 4'b0010;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd1, "TEST 10.3: 0010");

    // 0011: Inputs 0 and 1 asserted.
    d_i = 4'b0011;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd1, "TEST 10.4: 0011");

    // 0100: Input 2 asserted.
    d_i = 4'b0100;
    #1;
    check_result(1'b1, 2'd2, 1'b1, 2'd2, "TEST 10.5: 0100");

    // 0101: Inputs 0 and 2 asserted.
    d_i = 4'b0101;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd2, "TEST 10.6: 0101");

    // 0110: Inputs 1 and 2 asserted.
    d_i = 4'b0110;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd2, "TEST 10.7: 0110");

    // 0111: Inputs 0, 1 and 2 asserted.
    d_i = 4'b0111;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd2, "TEST 10.8: 0111");

    // 1000: Input 3 asserted.
    d_i = 4'b1000;
    #1;
    check_result(1'b1, 2'd3, 1'b1, 2'd3, "TEST 10.9: 1000");

    // 1001: Inputs 0 and 3 asserted.
    d_i = 4'b1001;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 10.10: 1001");

    // 1010: Inputs 1 and 3 asserted.
    d_i = 4'b1010;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd3, "TEST 10.11: 1010");

    // 1011: Inputs 0, 1 and 3 asserted.
    d_i = 4'b1011;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 10.12: 1011");

    // 1100: Inputs 2 and 3 asserted.
    d_i = 4'b1100;
    #1;
    check_result(1'b1, 2'd2, 1'b1, 2'd3, "TEST 10.13: 1100");

    // 1101: Inputs 0, 2 and 3 asserted.
    d_i = 4'b1101;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 10.14: 1101");

    // 1110: Inputs 1, 2 and 3 asserted.
    d_i = 4'b1110;
    #1;
    check_result(1'b1, 2'd1, 1'b1, 2'd3, "TEST 10.15: 1110");

    // 1111: All inputs asserted.
    d_i = 4'b1111;
    #1;
    check_result(1'b1, 2'd0, 1'b1, 2'd3, "TEST 10.16: 1111");
  endtask

  //////////////////////////////////////////////////////////////////////////////
  // MAIN TEST
  //////////////////////////////////////////////////////////////////////////////

  initial begin

    // Initialize DUT input to a known value before starting the test.
    d_i = '0;

    $display("\n");
    $display("============================================================");
    $display("      ADN COMMON PRIORITY ENCODER DIRECTED TESTBENCH");
    $display("============================================================");
    $display("NUM_WIRE = %0d", NUM_WIRE);

    // Only the selected test is executed unless TC_ALL is specified.
    case (test_name)
      "TC_001", "no_input": test_1_no_input();
      "TC_002", "single_input": test_2_single_input();
      "TC_003", "two_adjacent_inputs": test_3_two_adjacent_inputs();
      "TC_004", "two_non_adjacent_inputs": test_4_two_non_adjacent_inputs();
      "TC_005", "three_inputs": test_5_three_inputs();
      "TC_006", "all_inputs": test_6_all_inputs();
      "TC_007", "lowest_input_absent": test_7_lowest_input_absent();
      "TC_008", "highest_input_absent": test_8_highest_input_absent();
      "TC_009", "input_transition": test_9_input_transition();
      "TC_010", "exhaustive": test_10_exhaustive();

      "TC_ALL", "default": begin
        test_1_no_input();
        test_2_single_input();
        test_3_two_adjacent_inputs();
        test_4_two_non_adjacent_inputs();
        test_5_three_inputs();
        test_6_all_inputs();
        test_7_lowest_input_absent();
        test_8_highest_input_absent();
        test_9_input_transition();
        test_10_exhaustive();
      end
    endcase

    $display("\n============================================================");
    $display("              PRIORITY ENCODER TEST COMPLETE");
    $display("============================================================");

    $finish;

  end

endmodule
