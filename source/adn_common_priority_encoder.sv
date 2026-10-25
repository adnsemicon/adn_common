/*

### Purpose
This module implements a parameterized priority encoder that identifies the index of the first asserted bit in an input vector. It supports both low-index and high-index priority schemes, providing the binary address of the selected bit and a validity flag indicating if any input is active.

### Use-Case
This module is primarily used in arbitration logic, interrupt controllers, and resource allocation units where multiple requests arrive simultaneously, and a deterministic selection based on priority is required. By parameterizing the priority direction, it can be seamlessly integrated into both round-robin schedulers and fixed-priority bus masters.

| REVISION | DATE       | AUTHOR             | DESCRIPTION                                         |
|----------|------------|--------------------|-----------------------------------------------------|
| 0.1      | 2026-07-30 | Shykul Islam Siam  | Initial version                                     |
| 1.0      | 2026-07-30 | Shykul Islam Siam  | Stable release                                      |
| 1.1      | 2026-08-01 | Foez Ahmed         | Simplified logic                                    |
| 1.2      | 2026-08-01 | Foez Ahmed         | Ratified                                            |

Author : Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_priority_encoder #(
    // Number of input wires; must be at least two.
    parameter int NUM_WIRE            = 4,  
    // When set, the highest asserted input has priority.
    parameter bit HIGH_INDEX_PRIORITY = 0   
) (
    // Input vector to be encoded
    input logic [NUM_WIRE-1:0] d_i,

    // Binary encoded address of the highest/lowest priority bit
    output logic [$clog2(NUM_WIRE)-1:0] addr_o,
    // Validity flag: high if at least one bit in d_i is set
    output logic                        addr_valid_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Combinational logic to determine the priority index
  always_comb begin
    // Internal flag to track if a bit has been identified
    logic found;
    found = '0;
    addr_o = '0;
    addr_valid_o = '0;

    // Priority selection logic based on parameter
    if (HIGH_INDEX_PRIORITY) begin
      // Search from MSB to LSB for high-index priority
      for (int i = NUM_WIRE - 1; i >= 0; i--) begin
        if (d_i[i] && !found) begin
          addr_o = i;
          found  = 1'b1;
        end
      end
    end else begin
      // Search from LSB to MSB for low-index priority
      for (int i = 0; i < NUM_WIRE; i++) begin
        if (d_i[i] && !found) begin
          addr_o = i;
          found  = 1'b1;
        end
      end
    end
    // Assign validity based on whether any bit was found
    addr_valid_o = found;
  end

endmodule
