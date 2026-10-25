/*

### Purpose
This module provides a set of formal assertions for a pipeline split component. It validates the handshake protocol (valid/ready) on the upstream input interface and both downstream output interfaces (primary and secondary) to ensure data integrity and protocol compliance throughout the split operation.

### Use Case
This module is designed to be instantiated in formal verification environments or as a passive monitor in simulation for designs that implement a pipeline split (e.g., a 1-to-2 demultiplexer or a broadcast buffer). It ensures that the handshake signals adhere to the standard ready/valid protocol, preventing deadlocks or data loss when a single upstream stream is distributed to multiple downstream consumers.

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

module adn_common_pipeline_split_assertion #(
    parameter int DATA_WIDTH = 32  // Width of the data bus in bits
) (
    // Clock and Reset
    input logic arst_ni,  // Active-low asynchronous reset
    input logic clk_i,    // Rising-edge clock

    input logic clear_i,  // Synchronous clear to flush pipeline

    // Input (Upstream) Interface
    input  logic [DATA_WIDTH-1:0] data_in_i,        // Data payload from upstream
    input  logic                  data_in_valid_i,  // Valid signal for upstream data
    output logic                  data_in_ready_o,  // Ready signal to upstream

    // Output (Downstream) Interface - Secondary Path
    output logic [DATA_WIDTH-1:0] data_out_secondary_o,        // Secondary data payload
    output logic                  data_out_secondary_valid_o,  // Secondary valid signal
    input  logic                  data_out_secondary_ready_i,  // Secondary ready signal

    // Output (Downstream) Interface - Primary Path
    output logic [DATA_WIDTH-1:0] data_out_primary_o,        // Primary data payload
    output logic                  data_out_primary_valid_o,  // Primary valid signal
    input  logic                  data_out_primary_ready_i   // Primary ready signal
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Checker for the upstream input interface to ensure protocol compliance
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

  // Checker for the primary downstream interface
  adn_common_valid_ready_checker #(
      .DATA_WIDTH(DATA_WIDTH)
  ) a_out_p (
      .arst_ni(arst_ni),
      .rst_ni ('1),
      .clk_i  (clk_i),
      .data_i (data_out_primary_o),
      .valid_i(data_out_primary_valid_o),
      .ready_i(data_out_primary_ready_i)
  );

  // Checker for the secondary downstream interface with specific rule exclusions
  adn_common_valid_ready_checker #(
      .DATA_WIDTH(DATA_WIDTH),
      .IGNORE_RULE_0(1),
      .IGNORE_RULE_1(1)
  ) a_out_s (
      .arst_ni(arst_ni),
      .rst_ni ('1),
      .clk_i  (clk_i),
      .data_i (data_out_secondary_o),
      .valid_i(data_out_secondary_valid_o),
      .ready_i(data_out_secondary_ready_i)
  );

endmodule
