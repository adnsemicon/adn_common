/*

### Purpose
This module performs a binary-to-Gray code conversion. It takes a standard binary input and transforms it into a Gray code representation, which is essential for minimizing glitches in asynchronous clock domain crossings and multi-bit signal transitions.

### Use Case
This module is primarily used in digital systems where multi-bit signals must cross between different clock domains (e.g., FIFO pointers, counters). Because Gray code ensures that only one bit changes at a time between consecutive values, it prevents the metastable states that would otherwise occur if multiple bits were sampled simultaneously during a transition.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0      | 2026-07-29 | Foez Ahmed      | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Ratified                                               |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_bin_to_gray #(
    // Parameter defining the bit-width of the conversion logic
    parameter int WIDTH = 8
) (
    // Input binary vector to be converted
    input logic [WIDTH-1:0] bin_i,

    // Output Gray-coded vector
    output logic [WIDTH-1:0] gray_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Perform the conversion using the standard binary-to-Gray algorithm: G = B ^ (B >> 1)
  always_comb gray_o = bin_i ^ (bin_i >> 1);

endmodule
