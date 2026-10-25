/*

### Purpose
This module provides a standardized set of assertions for pipeline interfaces. It utilizes
`adn_common_valid_ready_checker` to verify that data, valid, and ready signals adhere to standard
handshake protocols at both the upstream input and downstream output boundaries of a pipeline stage.

### Use Case
This module is primarily used in digital design verification to ensure that pipeline stages maintain
data integrity and handshake protocol compliance. By instantiating this module at the boundaries of
a pipeline stage, designers can automatically detect protocol violations—such as data changing while
valid is high without a ready signal—thereby reducing debug time and ensuring robust communication
between upstream producers and downstream consumers.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-09 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-09 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pipeline_assertion #(
    parameter int DATA_WIDTH = 32  // Width of the data bus in bits
) (
    // Clock and Reset
    input logic arst_ni,  // Active-low asynchronous reset, must be stable
    input logic clk_i,    // System clock, rising-edge triggered

    input logic clear_i,  // Synchronous clear to flush pipeline

    // Input (Upstream) Interface
    input logic [DATA_WIDTH-1:0] data_in_i,  // Data payload from upstream producer
    input logic data_in_valid_i,  // Valid signal indicating data_in_i is stable
    input logic data_in_ready_o,  // Ready signal indicating upstream can accept data

    // Output (Downstream) Interface
    input logic [DATA_WIDTH-1:0] data_out_o,  // Data payload to downstream consumer
    input logic data_out_valid_o,  // Valid signal indicating data_out_o is stable
    input logic data_out_ready_i  // Ready signal indicating downstream can accept data
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Upstream interface protocol checker instance
  adn_common_valid_ready_checker #(
      .DATA_WIDTH(DATA_WIDTH)
  ) a_in (
      .arst_ni(arst_ni),
      .rst_ni ('1),
      .clk_i  (clk_i),
      .data_i (data_in_i),
      .valid_i(data_in_valid_i),
      .ready_i(data_in_ready_o)
  );

  // Downstream interface protocol checker instance
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

endmodule
