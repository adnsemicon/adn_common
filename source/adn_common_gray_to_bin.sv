/*

### Purpose
This module performs a combinatorial conversion of a Gray-coded input vector to its equivalent binary representation. It is designed to be generic, supporting arbitrary bit-widths defined by the `WIDTH` parameter.

### Use Case
This module is primarily used in clock domain crossing (CDC) interfaces, such as asynchronous FIFOs, where Gray code is employed to ensure that only one bit changes at a time between successive values. By converting the Gray-coded pointer back to binary, the system can perform arithmetic operations (like calculating FIFO depth or comparing pointers) that are not natively supported by Gray code.

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

module adn_common_gray_to_bin #(
    // Width of the input and output vectors
    parameter int WIDTH = 8
) (
    // Gray-coded input vector
    input logic [WIDTH-1:0] gray_i,

    // Binary-coded output vector
    output logic [WIDTH-1:0] bin_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // No internal signals required for this combinatorial logic

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Combinatorial block to perform Gray to Binary conversion
  always_comb begin
    // The Most Significant Bit (MSB) remains the same in both Gray and Binary
    bin_o[WIDTH-1] = gray_i[WIDTH-1];

    // Each subsequent bit is the XOR of the previous binary bit and the current Gray bit
    for (int i = WIDTH - 2; i >= 0; i--) begin
      bin_o[i] = bin_o[i+1] ^ gray_i[i];
    end
  end

endmodule
