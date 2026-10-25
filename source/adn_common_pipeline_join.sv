/*

### Purpose
This module implements a priority-based joiner for two input streams (primary and secondary). It multiplexes the input data into a single pipeline, prioritizing the primary stream while ensuring that secondary data is only processed when the primary stream is idle. The combined stream is then passed through a standard pipeline stage to maintain timing and flow control.

### Use Case
This module is ideal for scenarios where a high-priority control or data stream must be merged with a lower-priority background stream without stalling the primary path. Common applications include:
- **Interrupt Handling:** Merging asynchronous interrupt requests into a main processing pipeline.
- **Telemetry/Logging:** Injecting background diagnostic data into a primary data bus only when the bus is not actively transmitting high-priority payload.
- **Resource Sharing:** Allowing multiple masters to share a single downstream interface where one master is latency-sensitive and the other is throughput-oriented.

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

module adn_common_pipeline_join #(
    parameter int DATA_WIDTH = 32  // Data bus width
) (
    // Clock and Reset
    input logic arst_ni,  // Active-low asynchronous reset
    input logic clk_i,    // Rising-edge clock

    input logic clear_i,  // Synchronous clear to flush pipeline

    // Input (Upstream) Interface
    input  logic [DATA_WIDTH-1:0] data_in_secondary_i,        // Input data
    input  logic                  data_in_secondary_valid_i,  // Input data valid
    output logic                  data_in_secondary_ready_o,  // Input ready

    // Input (Upstream) Interface
    input  logic [DATA_WIDTH-1:0] data_in_primary_i,        // Input data
    input  logic                  data_in_primary_valid_i,  // Input data valid
    output logic                  data_in_primary_ready_o,  // Input ready

    // Output (Downstream) Interface
    output logic [DATA_WIDTH-1:0] data_out_o,        // Output data
    output logic                  data_out_valid_o,  // Output data valid
    input  logic                  data_out_ready_i   // Output ready
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] pl_data;  // Multiplexed data before pipeline
  logic                  pl_valid;  // Combined valid signal for pipeline
  logic                  pl_ready;  // Backpressure signal from pipeline

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Priority mux: select primary data if valid, otherwise secondary
  always_comb pl_data = data_in_primary_valid_i ? data_in_primary_i : data_in_secondary_i;

  // Valid signal: high if either input has valid data
  always_comb pl_valid = data_in_primary_valid_i | data_in_secondary_valid_i;

  // Flow control: primary always sees pipeline ready; secondary only sees ready if primary is idle
  always_comb data_in_primary_ready_o = pl_ready;
  always_comb data_in_secondary_ready_o = pl_ready & ~data_in_primary_valid_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Standard pipeline stage to register the multiplexed output
  adn_common_pipeline #(
      .DATA_WIDTH(DATA_WIDTH)
  ) u_pl (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .clear_i         (clear_i),
      .data_in_i       (pl_data),
      .data_in_valid_i (pl_valid),
      .data_in_ready_o (pl_ready),
      .data_out_o      (data_out_o),
      .data_out_valid_o(data_out_valid_o),
      .data_out_ready_i(data_out_ready_i)
  );

endmodule
