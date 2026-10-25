/*

### Purpose
This module computes a parity bit for a variable-length subset of an input data vector. It supports configurable data widths and provides dynamic selection between even and odd parity modes, allowing for flexible error detection across different data packet lengths.

### Use Case
This module is intended for use in communication interfaces, bus protocols, and memory controllers that require robust data integrity verification. It is particularly useful in systems where the number of active data bits changes dynamically, enabling a single hardware instance to handle various protocol-specific parity requirements.

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                        |
|----------|------------|---------------------|----------------------------------------------------|
| 0.1      | 2026-08-02 | Ahasan Ullah Khalid | Initial version                                    |
| 1.0      | 2026-08-09 | Ahasan Ullah Khalid | Stable release                                     |
| 1.1      | 2026-08-09 | Foez Ahmed          | Ratified                                           |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_parity_generator #(
    parameter int DATA_WIDTH = 8  // Width of the input data vector
) (
    input  logic [$clog2(DATA_WIDTH+1)-1:0] num_bits_i,     // Number of bits to consider
    input  logic [          DATA_WIDTH-1:0] data_i,         // Input data to calculate parity for
    input  logic                            parity_type_i,  // 0 for even parity, 1 for odd
    output logic                            parity_o        // Calculated parity bit
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] mask;  // Bitmask to isolate valid data bits

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // The mask logic performs a cumulative XOR operation across the input data vector.
  // By iteratively XORing each bit with the previous result, we effectively compute 
  // the parity of the subset of bits defined by num_bits_i.
  always_comb begin
    mask[0] = data_i[0];
    for (int i = 1; i < num_bits_i; i++) begin
      mask[i] = data_i[i] ^ mask[i-1];
    end
  end

  // Determine final parity output based on the selected parity type and the calculated mask.
  always_comb begin
    if (parity_type_i) begin
      // Odd parity: If no bits are selected, default to 1; otherwise, invert the cumulative XOR result.
      parity_o = (num_bits_i == '0) ? '1 : ~mask[num_bits_i-1];
    end else begin
      // Even parity: If no bits are selected, default to 0; otherwise, use the cumulative XOR result directly.
      parity_o = (num_bits_i == '0) ? '0 : mask[num_bits_i-1];
    end
  end

endmodule
