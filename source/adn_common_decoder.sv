/*

### Purpose
The `adn_common_decoder` module functions as a parameterized N-to-2^N one-hot decoder. It translates an input binary address into a one-hot encoded output signal, provided the input validity signal is asserted.

### Use-Case
This module is primarily used in memory-mapped systems, address decoding logic for peripheral selection, and state machine transitions where a binary-coded index needs to be converted into a specific enable signal for a target register or memory bank. It ensures that only one output line is active at a time, preventing bus contention and simplifying control signal routing.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-01 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-01 | Foez Ahmed      | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Ratified                                               |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_decoder #(
    parameter int ADDR_WIDTH = 2,               // Width of the input address bus
    parameter int DATA_WIDTH = (2 ** ADDR_WIDTH) // Width of the decoded output bus
) (
    input logic [ADDR_WIDTH-1:0] addr_i,        // Binary address input
    input logic                  addr_valid_i,  // Validity signal for the input address

    output logic [DATA_WIDTH-1:0] d_o           // One-hot decoded output
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Combinational logic block to perform the N-to-2^N decoding
  always_comb begin
    // Default output to zero to prevent latch inference and ensure inactive state
    d_o = '0;
    // Assert the specific bit corresponding to the binary address only if valid signal is high
    d_o[addr_i] = addr_valid_i;
  end

endmodule
