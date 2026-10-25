/*

# Purpose
The `adn_common_round_robin_arbiter` module implements a fair, round-robin arbitration scheme to select a single requester from multiple input requests. It ensures that every requester is granted access in a rotating order, preventing starvation and ensuring equitable bandwidth distribution among all input channels.

### Use Case
This module is primarily used in high-performance interconnects, such as:
- **Network-on-Chip (NoC) Routers:** To manage multiple input ports competing for a single output virtual channel.
- **Memory Controllers:** To arbitrate between multiple masters (e.g., CPU, DMA, GPU) requesting access to a shared memory interface.
- **Bus Interconnects:** To ensure fair access to shared peripheral buses where no single master should monopolize the bus bandwidth.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-07-28 | Motasim Faiyaz  | Initial version                                        |
| 1.0      | 2026-07-28 | Motasim Faiyaz  | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Simplified Logic                                       |
| 1.2      | 2026-08-01 | Foez Ahmed      | Ratified                                               |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_round_robin_arbiter #(
    // Number of request channels to arbitrate
    parameter int NUM_REQ = 8

) (
    // Clock input
    input logic clk_i,
    // Active-low asynchronous reset
    input logic arst_ni,

    // High when the arbiter is permitted to grant a new request
    input logic               allow_req_i,
    // Input request bus, one bit per channel
    input logic [NUM_REQ-1:0] req_i,

    // High when gnt_addr_o contains a valid grant
    output logic                       gnt_addr_valid_o,
    // Encoded grant address, original order
    output logic [$clog2(NUM_REQ)-1:0] gnt_addr_o,
    // One-hot grant output, original bit order
    output logic [        NUM_REQ-1:0] gnt_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Last granted request index
  logic [$clog2(NUM_REQ)-1:0] last_gnt;
  // Next potential grant index based on rotation
  logic [$clog2(NUM_REQ)-1:0] next_gnt;
  // Rotated input request bus
  logic [NUM_REQ-1:0]         fpa_in;
  // Encoded output from priority encoder
  logic [NUM_REQ-1:0]         fpa_out;
  // Priority encoder grant address
  logic [$clog2(NUM_REQ)-1:0] fpa_gnt_addr;
  // Priority encoder valid signal
  logic                       fpa_gnt_addr_valid;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  assign gnt_addr_o = ((fpa_gnt_addr + next_gnt ) < NUM_REQ) ? (fpa_gnt_addr + next_gnt )
                      : ((fpa_gnt_addr + next_gnt) - NUM_REQ);

  assign next_gnt = ((last_gnt + 1) < NUM_REQ) ? (last_gnt + 1) : ((last_gnt + 1) - NUM_REQ);

  assign gnt_addr_valid_o = fpa_gnt_addr_valid & arst_ni & allow_req_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_rotating_xbar #(
      .DATA_WIDTH(1),
      .NUM_PORTS (NUM_REQ)
  ) in_xbar (
      .rotation_index_i(next_gnt),
      .in_i(req_i),
      .out_o(fpa_in)
  );

  adn_common_priority_encoder #(
      .NUM_WIRE(NUM_REQ),
      .HIGH_INDEX_PRIORITY(0)
  ) prio_enc (
      .d_i(fpa_in),
      .addr_o(fpa_gnt_addr),
      .addr_valid_o(fpa_gnt_addr_valid)
  );

  adn_common_decoder #(
      .ADDR_WIDTH($clog2(NUM_REQ)),
      .DATA_WIDTH(NUM_REQ)
  ) decoder (
      .addr_i(gnt_addr_o),
      .addr_valid_i(gnt_addr_valid_o),
      .d_o(gnt_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      last_gnt <= NUM_REQ - 1;
    end else if (gnt_addr_valid_o) begin
      last_gnt <= gnt_addr_o;
    end
  end

endmodule
