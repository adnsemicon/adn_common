/*

### Purpose
The `adn_common_rotating_xbar` module implements a circular crossbar (or barrel shifter) switch. It routes a set of input ports to a corresponding set of output ports based on a dynamic rotation index, effectively performing a cyclic shift of the input data bus array.

### Use Case
This module is primarily used in high-performance interconnects, packet switching fabrics, and round-robin arbitration logic where data streams need to be dynamically remapped to different processing elements or memory banks without the overhead of a full non-blocking crossbar. It is ideal for scenarios requiring low-latency cyclic permutations of data buses.

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

module adn_common_rotating_xbar #(
    // Width of each individual data port in bits
    parameter int DATA_WIDTH = 2,
    // Total number of input and output ports in the crossbar
    parameter int NUM_PORTS  = 2
) (
    // Control signal defining the cyclic shift offset
    input logic [$clog2(NUM_PORTS)-1:0] rotation_index_i,
    // Array of input data buses
    input logic [NUM_PORTS-1:0][DATA_WIDTH-1:0] in_i,

    // Array of output data buses after cyclic permutation
    output logic [NUM_PORTS-1:0][DATA_WIDTH-1:0] out_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Combinational block to perform the cyclic rotation of input ports to output ports
  always_comb begin : gen_xbar
    for (int i = 0; i < NUM_PORTS; i++) begin
      // Map input index to output index using modulo arithmetic for circular shifting
      out_o[i] = in_i[(i+rotation_index_i)%NUM_PORTS];
    end
  end

endmodule
