/*
# Handshake Combiner Module

This module serves as a synchronization and aggregation unit that combines multiple handshake interfaces. It ensures that data transmission only proceeds when all input valid signals and all output ready signals are simultaneously asserted, effectively acting as a multi-channel AND-gate for handshake protocols.

## Use Case
The `adn_common_hs_combiner` is primarily used in high-performance interconnects and data-path pipelines where multiple independent data streams must be synchronized before being processed by a downstream consumer. By aggregating multiple handshake channels, it simplifies control logic in complex SoC architectures, ensuring that data-flow integrity is maintained across multi-channel interfaces without requiring individual state machines for every signal pair.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0      | 2026-07-22 | Foez Ahmed      | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Ratified                                               |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_hs_combiner #(
    parameter int NUM_TX = 2,  // Number of input handshake channels
    parameter int NUM_RX = 2   // Number of output handshake channels
) (
    // Input handshake interface signals
    input  logic [NUM_TX-1:0] valid_i,  // Input valid signals from source
    output logic [NUM_TX-1:0] ready_o,  // Output ready signals back to source

    // Output handshake interface signals
    output logic [NUM_RX-1:0] valid_o,  // Output valid signals to destination
    input  logic [NUM_RX-1:0] ready_i   // Input ready signals from destination
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Combinational logic block to evaluate handshake readiness
  always_comb begin
    logic ok_v;  // Aggregated valid status
    logic ok_r;  // Aggregated ready status
    logic ok;  // Global handshake synchronization signal

    // Check if all input valids are high
    ok_v = &valid_i;
    // Check if all output readies are high
    ok_r = &ready_i;
    // Transaction proceeds only if both conditions are met
    ok = ok_v & ok_r;

    // Drive output valid and ready signals based on synchronization status
    valid_o = ok ? '1 : '0;
    ready_o = ok ? '1 : '0;
  end

endmodule
