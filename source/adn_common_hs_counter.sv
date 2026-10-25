/*

### Purpose
This module implements a handshake-based counter designed to track the number of active data
elements within a buffer or pipeline stage. It monitors input and output handshakes to increment or
decrement the internal count, ensuring the counter remains within the bounds of the specified
`DEPTH`.

### Use Case
This module is primarily used in streaming architectures to manage flow control and occupancy
tracking. It is ideal for:
- **FIFO Depth Monitoring:** Tracking how many slots are currently occupied in a buffer.
- **Backpressure Management:** Generating `ready` signals based on current occupancy to prevent
buffer overflows.
- **Pipeline Monitoring:** Providing visibility into the number of valid data packets currently
traversing a multi-stage pipeline.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-07-27 | Annim Jannat    | Initial version                                        |
| 1.0      | 2026-07-29 | Annim Jannat    | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Ratified                                               |
| 1.2      | 2026-08-13 | Foez Ahmed      | Simplification                                         |

Author : Annim Jannat (jannatannim@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_hs_counter #(
    parameter int DEPTH     = 8,  // Maximum capacity of the buffer/pipeline
    parameter bit PIPELINED = 1   // Enable pipelined mode for higher throughput
) (
    input logic clk_i,   // System clock
    input logic arst_ni, // Active-low asynchronous reset

    input  logic data_in_valid_i,  // Input data valid signal
    output logic data_in_ready_o,  // Input data ready signal (backpressure)

    output logic [$clog2(DEPTH+1)-1:0] count_o,  // Current occupancy count
    output logic passing_through_o,  // Indicates data is passing through without buffering

    output logic data_out_valid_o,  // Output data valid signal
    input  logic data_out_ready_i   // Output data ready signal
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Handshake detection signals for input and output interfaces
  logic in_hs, out_hs;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // ready unless count is full
  always_comb data_in_ready_o = ((count_o != DEPTH) ? '1 : data_out_ready_i) & arst_ni;

  if (PIPELINED) begin
    // Pipelined mode: output valid is high only if counter is non-zero
    always_comb data_out_valid_o = (count_o != '0) & arst_ni;
  end else begin
    // Non-pipelined mode: output valid is high if counter is non-zero or input is valid
    always_comb data_out_valid_o = ((count_o != '0) ? '1 : data_in_valid_i) & arst_ni;
  end

  // handshake occurs when both valid and ready are asserted
  always_comb in_hs = data_in_valid_i && data_in_ready_o;
  // handshake occurs when both valid and ready are asserted
  always_comb out_hs = data_out_valid_o && data_out_ready_i;

  // Signal indicating data is bypassing the buffer when empty
  always_comb passing_through_o = data_out_valid_o & (count_o == '0);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Counter logic: increments on input handshake, decrements on output handshake
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      count_o <= '0;  // Reset counter to zero
    end else begin
      case ({
        in_hs, out_hs
      })
        'b01: count_o <= count_o - 1;
        'b10: count_o <= count_o + 1;
        default count_o <= count_o;
      endcase
    end
  end

endmodule
