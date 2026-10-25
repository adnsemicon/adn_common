/*

### Purpose
This module implements a pipeline splitter that takes a single upstream data stream and broadcasts
it to two downstream interfaces. It manages flow control by asserting readiness when either
downstream interface is ready, ensuring data is distributed according to the handshake logic of the
connected consumers.

### Use Case
The `adn_common_pipeline_split` module is primarily used in high-performance data path architectures
where a single data source needs to be replicated to multiple processing units or monitoring
interfaces simultaneously. Common scenarios include:
- **Data Mirroring:** Sending a copy of the data stream to a debug/trace unit while the primary
stream continues to the main processing logic.
- **Parallel Processing:** Distributing the same input data to two different functional blocks that
operate on the data concurrently.
- **Redundancy:** Feeding identical data to two identical hardware modules to implement
fault-tolerant or lock-step checking mechanisms.

### Warnings
The module prioritizes the primary output interface. If both the downstream interfaces are not 
ready, the secondary output will see valid, but when on the next cycle, both are ready, the
secondary will not see valid signal being asserted. This behavior is by design to ensure that the
primary output has precedence in receiving data. This violates the typical handshake protocol,
however, this is the intended behavior.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-06 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-06 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pipeline_split #(
    parameter int DATA_WIDTH = 32  // Data bus width
) (
    // Clock and Reset
    input logic arst_ni,  // Active-low asynchronous reset
    input logic clk_i,    // Rising-edge clock

    input logic clear_i,  // Synchronous clear to flush pipeline

    // Input (Upstream) Interface
    input  logic [DATA_WIDTH-1:0] data_in_i,        // Input data
    input  logic                  data_in_valid_i,  // Input data valid
    output logic                  data_in_ready_o,  // Input ready

    // Output (Downstream) Interface
    output logic [DATA_WIDTH-1:0] data_out_secondary_o,        // Output data
    output logic                  data_out_secondary_valid_o,  // Output data valid
    input  logic                  data_out_secondary_ready_i,  // Output ready

    // Output (Downstream) Interface
    output logic [DATA_WIDTH-1:0] data_out_primary_o,        // Output data
    output logic                  data_out_primary_valid_o,  // Output data valid
    input  logic                  data_out_primary_ready_i   // Output ready
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] pl_data;  // Internal pipeline data bus
  logic                  pl_valid;  // Internal pipeline valid signal
  logic                  pl_ready;  // Internal pipeline ready signal

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Broadcast pipeline data to both primary and secondary outputs
  always_comb data_out_primary_o = pl_data;
  always_comb data_out_secondary_o = pl_data;

  // Primary valid is direct; secondary valid is gated by primary ready status
  always_comb data_out_primary_valid_o = pl_valid;
  always_comb data_out_secondary_valid_o = pl_valid & ~data_out_primary_ready_i;

  // Pipeline is ready if either downstream interface can accept data
  always_comb pl_ready = data_out_primary_ready_i | data_out_secondary_ready_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pipeline stage to buffer and synchronize upstream data
  adn_common_pipeline #(
      .DATA_WIDTH(DATA_WIDTH)
  ) u_pl (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .clear_i         (clear_i),
      .data_in_i       (data_in_i),
      .data_in_valid_i (data_in_valid_i),
      .data_in_ready_o (data_in_ready_o),
      .data_out_o      (pl_data),
      .data_out_valid_o(pl_valid),
      .data_out_ready_i(pl_ready)
  );

endmodule
