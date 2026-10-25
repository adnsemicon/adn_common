/*

| TEST CASE| DATE       | AUTHOR            | DESCRIPTION                                             |
|----------|------------|-------------------|---------------------------------------------------------|  
| TC_01    | 2026-08-02 | Shykul Islam Siam | Idle state verification with no requests active         |
| TC_02    | 2026-08-02 | Shykul Islam Siam | Single isolated requests arbitration                    |
| TC_03    | 2026-08-02 | Shykul Islam Siam | Continuous round-robin rotation with all requests high  | 
| TC_04    | 2026-08-02 | Shykul Islam Siam | Sparse requests arbitration (skipping inactive ports)   |
| TC_05    | 2026-08-02 | Shykul Islam Siam | Disable arbitration via allow_req_i signal              | 
| TC_06    | 2026-08-02 | Shykul Islam Siam | Asynchronous active-low reset verification              |

| REVISION | DATE       | AUTHOR            | DESCRIPTION                                             |
|----------|------------|-------------------|---------------------------------------------------------|
| 0.1      | 2026-08-02 | Shykul Islam Siam | Initial version                                         |
| 1.0      | 2026-08-02 | Shykul Islam Siam | Stable release                                          |

Author : Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_round_robin_arbiter_tb; 

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv" // Import shared testbench utilities and macros.

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int NUM_REQ = 4; // Number of arbitration requesters under test.
  localparam time CLK_PERIOD = 10ns; // Clock period used by the testbench.


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                       clk_i; // DUT clock.
  logic                       arst_ni; // Active-low asynchronous reset.
  logic                       allow_req_i; // Global arbitration enable.
  logic [NUM_REQ-1:0]         req_i; // Per-requester request vector.

  logic                       gnt_addr_valid_o; // Indicates a valid grant address.
  logic [$clog2(NUM_REQ)-1:0] gnt_addr_o; // Encoded index of the granted requester.
  logic [NUM_REQ-1:0]         gnt_o; // One-hot grant vector.

  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_round_robin_arbiter #( // Instantiate the round-robin arbiter DUT.
      .NUM_REQ(NUM_REQ) // Match the DUT requester count to the testbench.
  ) u_dut ( // Name the DUT instance.
      .clk_i           (clk_i), // Drive the DUT clock.
      .arst_ni         (arst_ni), // Drive the DUT asynchronous reset.
      .allow_req_i     (allow_req_i), // Drive the DUT arbitration enable.
      .req_i           (req_i), // Drive the DUT request vector.
      .gnt_addr_valid_o(gnt_addr_valid_o), // Observe grant-valid status.
      .gnt_addr_o      (gnt_addr_o), // Observe encoded grant address.
      .gnt_o           (gnt_o) // Observe one-hot grant vector.
  ); // Finish DUT port connections.

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic reset_dut(); // Reset the DUT and restore normal arbitration enable.
    arst_ni     = 1'b0; // Assert the active-low reset.
    allow_req_i = 1'b0; // Prevent arbitration while resetting.
    req_i       = '0; // Remove all pending requests.
    repeat (2) @(posedge clk_i); // Hold reset for two rising clock edges.
    arst_ni     = 1'b1; // Release the asynchronous reset.
    allow_req_i = 1'b1; // Re-enable arbitration.
    @(posedge clk_i); // Allow the DUT state to settle after reset.
  endtask // reset_dut

  task automatic check_grant(input logic exp_valid, input logic [$clog2(NUM_REQ)-1:0] exp_addr); // Compare DUT outputs against an expected grant.
    logic pass; // Stores the result of this check.
    #1ps; // Sample after combinational logic has settled.
    if (exp_valid) begin // Check a valid, one-hot grant.
      pass = (gnt_addr_valid_o == 1'b1) && (gnt_addr_o == exp_addr) && (gnt_o == (1 << exp_addr)) && $onehot(gnt_o); // Require matching valid, address, and one-hot grant signals.
      note_case(pass); // Record the result in the shared testbench scoreboard.
      if (pass) begin // Report a successful valid-grant check.
        $display("[PASS] Expected addr=%0d, Got valid=%0b addr=%0d gnt_o=%0b", exp_addr, gnt_addr_valid_o, gnt_addr_o, gnt_o); // Print observed grant details.
      end else begin // Report a failed valid-grant check.
        $display("[FAIL] Expected addr=%0d, Got valid=%0b addr=%0d gnt_o=%0b", exp_addr, gnt_addr_valid_o, gnt_addr_o, gnt_o); // Print observed grant details.
      end // pass
    end else begin // Check that the DUT reports no grant.
      pass = (gnt_addr_valid_o == 1'b0) && (gnt_o == '0); // Require invalid status and an all-zero grant vector.
      note_case(pass); // Record the result in the shared testbench scoreboard.
      if (pass) begin // Report a successful idle check.
        $display("[PASS] Expected invalid grant, Got valid=%0b gnt_o=%0b", gnt_addr_valid_o, gnt_o); // Print observed idle outputs.
      end else begin // Report a failed idle check.
        $display("[FAIL] Expected invalid grant, Got valid=%0b gnt_o=%0b", gnt_addr_valid_o, gnt_o); // Print observed idle outputs.
      end // pass
    end // exp_valid
  endtask // check_grant

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always #(CLK_PERIOD / 2) clk_i = ~clk_i; // Generate a free-running clock.

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // Execute all test cases once at simulation start.

    clk_i = 1'b0; // Initialize the clock before the oscillator starts toggling.
    reset_dut(); // Put the DUT into a known operating state.

    // TC_01: Idle State Verification (No Requests)
    req_i = 4'b0000; // Present no active requests.
    check_grant(1'b0, 0); // Expect no valid grant.

    // TC_02: Single Isolated Request Test
    req_i = 4'b0001; // Request service only from requester 0.
    check_grant(1'b1, 0); // Expect requester 0 to be granted.
    @(posedge clk_i); // Advance arbitration state by one cycle.

    req_i = 4'b0100; // Request service only from requester 2.
    check_grant(1'b1, 2); // Expect requester 2 to be granted.
    @(posedge clk_i); // Advance arbitration state by one cycle.

    // TC_03: Continuous Round Robin Rotation (All Requests High)
    req_i = 4'b1111; // Assert requests from every requester.
    check_grant(1'b1, 3); @(posedge clk_i); // Expect requester 3, then advance the rotation.
    check_grant(1'b1, 0); @(posedge clk_i); // Expect requester 0, then advance the rotation.
    check_grant(1'b1, 1); @(posedge clk_i); // Expect requester 1, then advance the rotation.
    check_grant(1'b1, 2); @(posedge clk_i); // Expect requester 2, then advance the rotation.

    // TC_04: Sparse Requests Rotation (Ports 1 and 3)
    req_i = 4'b1010; // Assert requests only from requesters 1 and 3.
    check_grant(1'b1, 3); @(posedge clk_i); // Expect requester 3, then advance the rotation.
    check_grant(1'b1, 1); @(posedge clk_i); // Expect requester 1, then advance the rotation.
    check_grant(1'b1, 3); @(posedge clk_i); // Verify that inactive requesters are skipped.

    // TC_05: Global Enable Control (allow_req_i)
    req_i = 4'b1111; // Keep every requester active for enable testing.
    allow_req_i = 1'b0; // Disable arbitration globally.
    check_grant(1'b0, 0); // Expect all grants to be suppressed.

    allow_req_i = 1'b1; // Re-enable arbitration.
    check_grant(1'b1, 0); // Expect arbitration to resume from requester 0.
    @(posedge clk_i); // Advance arbitration state by one cycle.

    // TC_06: Asynchronous Reset Verification
    arst_ni = 1'b0; // Assert reset asynchronously.
    #1ps; // Allow the asynchronous reset to propagate.
    check_grant(1'b0, 0); // Expect reset to clear all grants immediately.

    reset_dut(); // Restore normal operation after reset verification.
    req_i = 4'b1111; // Reassert all requests after reset.
    check_grant(1'b1, 0); // Expect reset to restore the initial rotation position.

    $finish; // End the simulation after all test cases pass or fail.

  end // initial

endmodule // adn_common_round_robin_arbiter_tb
