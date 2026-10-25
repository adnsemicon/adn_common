/*

### Purpose
This module implements a generic crossbar switch (xbar) that routes data from multiple input ports to multiple output ports based on provided selection signals. It supports configurable data widths and input/output counts, providing a flexible interconnect solution for data path routing.

### Use Case
The `adn_common_xbar` is designed for high-performance interconnect fabrics where multiple data sources must be dynamically routed to specific destinations. Common use cases include:
- **Memory Interconnects:** Routing data from multiple cache controllers to shared memory banks.
- **NoC (Network-on-Chip) Routers:** Serving as the primary switching fabric within a router node.
- **Peripheral Bus Switching:** Connecting multiple master peripherals to various slave interfaces in a SoC.
- **Data Path Multiplexing:** Efficiently selecting data streams in DSP or signal processing pipelines to reduce logic overhead.

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

module adn_common_xbar #(
    // Width of the data bus in bits
    parameter int DATA_WIDTH  = 2,
    // Number of input ports
    parameter int NUM_INPUTS  = 2,
    // Number of output ports
    parameter int NUM_OUTPUTS = 2
) (
    // Selection signals for each output port (index of input to route)
    input logic [NUM_OUTPUTS-1:0][$clog2(NUM_INPUTS)-1:0] sel_i,
    // Input data ports array
    input logic [NUM_INPUTS-1:0][DATA_WIDTH-1:0] in_i,

    // Output data ports array
    output logic [NUM_OUTPUTS-1:0][DATA_WIDTH-1:0] out_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Combinational logic block to route inputs to outputs based on selection signals
  always_comb begin : gen_xbar
    // Iterate through each output port and assign the selected input port data
    for (int i = 0; i < NUM_OUTPUTS; i++) begin
      out_o[i] = in_i[sel_i[i]];
    end
  end

endmodule
