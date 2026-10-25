/*

### Purpose
This module performs a range comparison to determine if a given address falls within a specified
inclusive-minimum and exclusive-maximum range. It is designed to be used in memory-mapped systems or
address decoding logic to validate address access.

### Usage
To use this module, instantiate it by specifying the `WIDTH` parameter to match your system's 
address bus width. Connect the lower bound of the range to `min_i`, the upper bound (exclusive) to
`max_i`, and the address to be checked to `value_i`. The `match_o` output will assert high if
`min_i <= value_i < max_i`.

| REVISION | DATE       | AUTHOR             | DESCRIPTION                                         |
|----------|------------|--------------------|-----------------------------------------------------|
| 1.0      | 2026-07-30 | Adnan Sami Anirban | Stable release                                      |
| 1.1      | 2026-08-06 | Foez Ahmed         | Ratified                                            |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_range_checker #(
    // Parameter defining the bit-width of the signals
    parameter int WIDTH = 32
) (
    // Inclusive lower bound of the range
    input logic [WIDTH-1:0] min_i,
    // Exclusive upper bound of the range
    input logic [WIDTH-1:0] max_i,
    // value to be checked against the defined range
    input logic [WIDTH-1:0] value_i,

    // Output signal: High if value_i is within [min_i, max_i)
    output logic match_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Functional block to perform the range comparison logic.
  // The address matches if the range is valid (min < max) and the address 
  // falls within the inclusive-lower and exclusive-upper bounds.
  always_comb begin
    match_o = (min_i < max_i) && (value_i >= min_i) && (value_i < max_i);
  end

endmodule
