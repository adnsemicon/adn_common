/*

### Purpose
This module serves as a verification wrapper that integrates `adn_common_valid_ready_checker` instances across all primary, secondary, and output interfaces. Its primary function is to enforce and monitor handshake protocol compliance (valid/ready) within a pipeline join structure, ensuring data integrity and flow control correctness during simulation.

### Use Case
This module is utilized in pipeline join architectures where multiple upstream data streams (primary and secondary) are merged into a single downstream interface. By instantiating this module, designers can automatically verify that the handshake logic at each interface adheres to the AXI-style valid/ready protocol, preventing common bugs such as data loss, protocol deadlocks, or illegal state transitions during high-speed data movement.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-09 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-08-09 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pipeline_join_assertion #(
    parameter int DATA_WIDTH = 32  // Width of the data bus in bits
) (
    // Clock and Reset
    input logic arst_ni,  // Active-low asynchronous reset
    input logic clk_i,    // Rising-edge clock signal

    input logic clear_i,  // Synchronous clear to flush pipeline

    // Input (Upstream) Secondary Interface
    input  logic [DATA_WIDTH-1:0] data_in_secondary_i,        // Secondary input data bus
    input  logic                  data_in_secondary_valid_i,  // Secondary input valid signal
    output logic                  data_in_secondary_ready_o,  // Secondary input ready signal

    // Input (Upstream) Primary Interface
    input  logic [DATA_WIDTH-1:0] data_in_primary_i,        // Primary input data bus
    input  logic                  data_in_primary_valid_i,  // Primary input valid signal
    output logic                  data_in_primary_ready_o,  // Primary input ready signal

    // Output (Downstream) Interface
    output logic [DATA_WIDTH-1:0] data_out_o,        // Downstream output data bus
    output logic                  data_out_valid_o,  // Downstream output valid signal
    input  logic                  data_out_ready_i   // Downstream output ready signal
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Checker for the downstream output interface
  adn_common_valid_ready_checker #(
      .DATA_WIDTH(DATA_WIDTH)
  ) a_out (
      .arst_ni(arst_ni),
      .rst_ni ('1),
      .clk_i  (clk_i),
      .data_i (data_out_o),
      .valid_i(data_out_valid_o),
      .ready_i(data_out_ready_i)
  );

  // Checker for the primary upstream interface
  adn_common_valid_ready_checker #(
      .DATA_WIDTH(DATA_WIDTH)
  ) a_in_p (
      .arst_ni(arst_ni),
      .rst_ni ('1),
      .clk_i  (clk_i),
      .data_i (data_in_primary_i),
      .valid_i(data_in_primary_valid_i),
      .ready_i(data_in_primary_ready_o)
  );

  // Checker for the secondary upstream interface
  adn_common_valid_ready_checker #(
      .DATA_WIDTH(DATA_WIDTH)
  ) a_in_s (
      .arst_ni(arst_ni),
      .rst_ni ('1),
      .clk_i  (clk_i),
      .data_i (data_in_secondary_i),
      .valid_i(data_in_secondary_valid_i),
      .ready_i(data_in_secondary_ready_o)
  );

endmodule
