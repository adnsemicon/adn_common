/*

### Purpose
This module implements a priority encoder that converts a multi-bit input vector into its corresponding binary index. It identifies the position of the active bit and provides a validity signal to indicate if any input wire is asserted.

### Use Case
This module is primarily used in arbitration logic, interrupt controllers, and resource allocation systems where multiple request lines exist, and the system needs to determine the highest-priority active request to grant access to a shared resource. It is highly efficient for mapping sparse one-hot or multi-bit signals into a compact binary representation for downstream address decoding or state machine transitions.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-29 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-29 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_encoder #(
    parameter int NUM_WIRE = 16 // Total number of input wires to be encoded
) (
    input logic [NUM_WIRE-1:0] wire_in, // Input vector to be priority encoded

    output logic [$clog2(NUM_WIRE)-1:0] index_o, // Encoded binary index output
    output logic                        index_valid_o // High when at least one input wire is active
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Array to hold intermediate reduction results for each level of the encoder tree
  logic [NUM_WIRE/2-1:0] index_or_red[$clog2(NUM_WIRE)];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Generate block to calculate reduction for each level of the priority logic
  for (genvar j = 0; j < $clog2(NUM_WIRE); j++) begin : g_addr_or_red
    // Combinational logic block to process bit-wise reduction per level
    always_comb begin
      int k;
      index_or_red[j] = '0;  // Initialize reduction array to 0
      k = 0;
      for (int i = 0; i < NUM_WIRE; i++) begin
        // Condition to include the wire in the current reduction level based on bit significance
        if (!((i % (2 ** (j + 1))) < ((2 ** (j + 1)) / 2))) begin
          index_or_red[j][k] = wire_in[i];  // Assign wire to reduction array
          k++;
        end
      end
    end
  end

  // Generate block to assign output index based on the reduction results from the tree
  for (genvar i = 0; i < $clog2(NUM_WIRE); i++) begin : g_addr_o
    // OR reduction results to form the specific bit of the output index
    always_comb index_o[i] = |index_or_red[i];
  end

  // Determine if any input wire is active to set the validity flag
  always_comb index_valid_o = |wire_in;

endmodule
