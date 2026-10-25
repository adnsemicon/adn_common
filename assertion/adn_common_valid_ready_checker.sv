/*

### Purpose
The `adn_common_valid_ready_checker` module serves as a verification component designed to monitor and enforce protocol compliance for AXI-style handshake interfaces. It utilizes SystemVerilog assertions to ensure that data remains stable during stalls, reset signals are handled correctly, and handshake signals adhere to expected timing behaviors.

### Use Case
This module is primarily used in RTL verification environments to act as a passive monitor for AXI-Stream or similar ready/valid handshake interfaces. It is instantiated alongside design modules to:
- Detect protocol violations during simulation without impacting the design's functional logic.
- Ensure data integrity by verifying that the payload remains stable when a transaction is stalled (valid high, ready low).
- Validate reset behavior by ensuring that handshake signals are de-asserted correctly during asynchronous and synchronous reset sequences.
- Provide immediate feedback via assertion errors, significantly reducing debug time for handshake-related bugs.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-09 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-09 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_valid_ready_checker #(
    // Width of the data bus being monitored
    parameter int DATA_WIDTH = 8,
    // Disable rule 0: Data stability check
    parameter bit IGNORE_RULE_0 = 0,
    // Disable rule 1: Handshake timing check
    parameter bit IGNORE_RULE_1 = 0,
    // Disable rule 2: Sync reset check for VALID
    parameter bit IGNORE_RULE_2 = 0,
    // Disable rule 3: Sync reset check for READY
    parameter bit IGNORE_RULE_3 = 0,
    // Disable rule 4: Async reset check for VALID
    parameter bit IGNORE_RULE_4 = 0,
    // Disable rule 5: Async reset check for READY
    parameter bit IGNORE_RULE_5 = 0,
    // Disable rule 6: Async reset de-assertion check for VALID
    parameter bit IGNORE_RULE_6 = 0,
    // Disable rule 7: Async reset de-assertion check for READY
    parameter bit IGNORE_RULE_7 = 0
) (
    input logic arst_ni,  // Asynchronous active-low reset
    input logic rst_ni,   // Synchronous active-low reset

    input logic clk_i,  // System clock

    input logic [DATA_WIDTH-1:0] data_i,   // Data payload to monitor for stability
    input logic                  valid_i,  // Valid signal from the source
    input logic                  ready_i   // Ready signal from the destination
);

  /* verilog_format: off*/

  // Assertion: Ensure data stability during stall (Valid high, Ready low)
  if (IGNORE_RULE_0 == 0) begin
    assert property (@(posedge clk_i) if (arst_ni && rst_ni)
      (valid_i && !ready_i) |=> $stable(data_i))
    else
      $error("ASSERTION FAILED: BUS should remain stable when VALID is high and READY is low");
  end

  // Assertion: Check handshake protocol timing
  if (IGNORE_RULE_1 == 0) begin
    assert property (@(posedge clk_i) if (arst_ni && rst_ni)
      ($past(valid_i) && !valid_i) |=> $past(ready_i, 2))
    else
      $error("ASSERTION FAILED: READY should be high when VALID goes low");
  end

  // Assertion: Validate synchronous reset behavior for VALID
  if (IGNORE_RULE_2 == 0) begin
    assert property (@(posedge clk_i)
      !rst_ni |=> !valid_i)
    else
      $error("ASSERTION FAILED: VALID must be low when reset is asserted");
  end

  // Assertion: Validate synchronous reset behavior for READY
  if (IGNORE_RULE_3 == 0) begin
    assert property (@(posedge clk_i)
      !rst_ni |=> !ready_i)
    else
      $error("ASSERTION FAILED: READY must be low when reset is asserted");
  end

  // Assertion: Validate asynchronous reset behavior for VALID
  if (IGNORE_RULE_4 == 0) begin
    assert property (@(posedge clk_i) // PROBABLY JHAMELA
      !arst_ni |-> !valid_i)
    else
      $error("ASSERTION FAILED: VALID must be low when reset is asserted");
  end

  // Assertion: Validate asynchronous reset behavior for READY
  if (IGNORE_RULE_5 == 0) begin
  assert property (@(posedge clk_i) // PROBABLY JHAMELA
    !arst_ni |-> !ready_i)
  else
    $error("ASSERTION FAILED: READY must be low when reset is asserted");
  end

  /* verilog_format: on*/

  // Block: Asynchronous reset monitoring
  always @(negedge arst_ni) begin
    #1step;
    // Verify signals are de-asserted immediately upon async reset

    if (IGNORE_RULE_6 == 0) begin
      assert (!valid_i)
      else $error("ASSERTION FAILED: VALID must be low when reset is asserted");
    end

    if (IGNORE_RULE_7 == 0) begin
      assert (!ready_i)
      else $error("ASSERTION FAILED: READY must be low when reset is asserted");
    end
  end

endmodule
