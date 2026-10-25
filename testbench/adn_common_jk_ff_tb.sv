/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|  
| TC_001    | YYYY-MM-DD | Adnan Sami Anirban | Test case description goes here                       |
| TC_002    | YYYY-MM-DD | Adnan Sami Anirban | Test case description goes here                       |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | YYYY-MM-DD | Adnan Sami Anirban | Initial version                                        |
| 1.0      | YYYY-MM-DD | Adnan Sami Anirban | Stable release                                         |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_jk_ff_tb;

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic   arst_ni;
  logic   clk_i;
  logic   j_i;
  logic   k_i;
  logic   q_o;

  always #5 clk_i = ~clk_i; // Clock generation with a period of 10 time units

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_common_jk_ff dut (
    .arst_ni   (arst_ni),
    .clk_i     (clk_i  ),
    .j_i       (j_i    ),
    .k_i       (k_i    ),
    .q_o       (q_o    )
  );
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic apply_reset();
    arst_ni <= 1'b0;
    j_i     <= 1'b0;
    k_i     <= 1'b0;
    #22;
    arst_ni <= 1'b1;
  endtask

  task automatic apply_input(input logic j_val, input logic k_val);
  @(negedge clk_i);
    j_i <= j_val;
    k_i <= k_val;
    $display("\033[1;33mApplying Inputs\033[0m: j_i = %b, k_i = %b", j_val, k_val);
  endtask


  task automatic check_output(input logic expected_q);
    @(posedge clk_i);
    #2;
    if (q_o !== expected_q) begin
      $display("\033[1;31mTest Failed\033[0m: Expected q_o = %b, but got %b", expected_q, q_o);
      note_case(0);
    end else begin
      $display("\033[1;32mTest Passed\033[0m: q_o = %b as expected", q_o);
      note_case(1);
    end
  endtask

  function automatic bit exp_val(input bit j_val, input bit k_val);
  case ({j_val, k_val})
    2'b00: return q_o;        // Hold state
    2'b01: return 1'b0;       // Reset state
    2'b10: return 1'b1;       // Set state
    2'b11: return ~q_o;       // Toggle state
    default: return q_o;      // Default case (should not occur)
  endcase
  endfunction



  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    $dumpfile("adn_common_jk_ff_tb.vcd");
    $dumpvars(0, adn_common_jk_ff_tb);
    $display("Starting JK Flip-Flop Testbench...");
    arst_ni = 1'b0;
    clk_i   = 1'b0;
    j_i     = 1'b0;
    k_i     = 1'b0;

    #12ns arst_ni = 1'b1; // Release reset after 12 time units

    // Test sequence
// Testcase 1: Hold state
$display("\033[1;34mTestcase 1: Hold state\033[0m");
    apply_input(1'b0, 1'b0); // Hold state
    check_output(q_o);       // Expect q_o = 0
// Testcase 2: Set state
$display("\033[1;34mTestcase 2: Set state\033[0m");
    apply_input(1'b1, 1'b0); // Set state
    check_output(1'b1);      // Expect q_o = 1
// Testcase 3: Reset state
$display("\033[1;34mTestcase 3: Reset state\033[0m");
    apply_input(1'b0, 1'b1); // Reset state
    check_output(1'b0);      // Expect q_o = 0
// Testcase 4: Toggle state
$display("\033[1;34mTestcase 4: Toggle state\033[0m");
    apply_input(1'b1, 1'b1); // Toggle state
    check_output(~q_o);      // Expect q_o = 1


// Testcase 5: Multiple toogles state
// Toggle state multiple times to verify toggling behavior
$display("\033[1;34mTestcase 5: Multiple toggles state\033[0m");
    for (int i = 0; i < 5; i++) begin
      apply_input(1'b1, 1'b1); // Toggle state
      check_output(~q_o);      // Expect q_o to toggle
    end


// Testcase 6: Random j and k inputs for 20 cycles
$display("\033[1;34mTestcase 6: Random j and k inputs for 20 cycles\033[0m");
    for (int i = 0; i<20; i++) begin 
      automatic bit rand_j = $urandom_range(0,1);
      automatic bit rand_k = $urandom_range(0,1);
      automatic bit expected_q = exp_val(rand_j, rand_k);
      apply_input(rand_j, rand_k);
      check_output(expected_q);
    end

// Testcase 7: Reset during operation
$display("\033[1;34mTestcase 7: Reset during operation\033[0m");
    apply_input(1'b1, 1'b0); // Set state
    check_output(1'b1);      // Expect q_o = 1
//fork
    apply_reset();
    check_output(1'b0); // Expect q_o = 0 after reset
//join

// set j=1, k=0 and check if q_o goes to 1
$display("\033[1;34mTestcase 8: Set state after reset\033[0m");
    apply_input(1'b1, 1'b0);
    check_output(1'b1); // Expect q_o = 1 after set 

    #30 $finish;
  end
endmodule
