/*

### Purpose
The `adn_common_synchronizer` module is a generic multi-stage flip-flop synchronizer designed to safely transfer asynchronous signals between different clock domains. It mitigates metastability issues by passing the input data through a configurable number of sequential stages before outputting the synchronized signal.

### Use Case
This module is primarily used when a signal originates in one clock domain and must be sampled by logic in a different clock domain. By utilizing a chain of flip-flops, it provides the necessary settling time for the signal to stabilize, effectively preventing metastability from propagating into the destination domain's logic. It is ideal for control signals, status flags, and single-bit handshaking protocols where data integrity across clock boundaries is critical.

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                        |
|----------|------------|---------------------|----------------------------------------------------|
| 0.1      | 2026-07-28 | Ahasan Ullah Khalid | Initial version                                    |
| 1.0      | 2026-07-28 | Ahasan Ullah Khalid | Stable release                                     |
| 1.1      | 2026-08-01 | Foez Ahmed          | Ratified                                           |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`include "adn_common_synth_directives.svh"

module adn_common_synchronizer #(
    parameter int WIDTH = 1,  // Bit width of the data bus
    parameter int STAGES = 2,  // Number of synchronization stages (min 2 recommended)
    parameter logic [WIDTH-1:0] RESET_VALUE = '0  // Value to load during reset
) (
    input logic clk_i,    // Destination clock domain
    input logic arst_ni,  // Active-low asynchronous reset
    input logic en_i,     // Enable signal for synchronization stages

    input logic [WIDTH-1:0] data_i,  // Asynchronous input data

    output logic [WIDTH-1:0] data_o  // Synchronized output data
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Array of registers representing the multi-stage synchronization chain
  logic [WIDTH-1:0] sync_ff[STAGES];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Multi-stage flip-flop chain to resolve metastability
  always_ff @(posedge clk_i or negedge arst_ni) begin

    if (!arst_ni) begin
      // Reset all stages to the defined reset value
      for (int i = 0; i < STAGES; i++) sync_ff[i] <= RESET_VALUE;
    end else if (en_i) begin
      // Shift input data through the synchronization stages
      sync_ff[0] <= data_i;
      for (int i = 1; i < STAGES; i++) sync_ff[i] <= sync_ff[i-1];
    end

  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Output the final stage of the synchronization chain
  always_comb data_o = sync_ff[STAGES-1];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  initial begin
    if (STAGES > 3) begin
      $display("\033[1;33m%m Is %0d stages actually necessary?\033[0m", STAGES);
    end
  end
`endif  // SIMULATION

endmodule
