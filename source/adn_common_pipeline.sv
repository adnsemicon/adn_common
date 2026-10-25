/*

### Purpose
The `adn_common_pipeline` module implements a single-stage pipeline register with a standard ready/valid handshake protocol. It acts as a buffer to decouple timing paths between upstream and downstream modules, allowing for improved clock frequency by inserting a register stage in the data path while maintaining flow control. It includes a synchronous clear signal to flush the pipeline.

### Use Case
This module is primarily used in high-speed digital designs to break long combinational paths. By inserting this pipeline stage between two modules, you can effectively "cut" the critical path, allowing the design to meet tighter timing constraints. It is ideal for:
- **Inter-module communication:** Buffering data between modules operating on different logic levels or physical distances.
- **Backpressure handling:** Managing data flow when the downstream module is temporarily unable to accept new data (e.g., due to a full FIFO or busy state).
- **Timing closure:** Improving the maximum operating frequency ($F_{max}$) of the design by adding a single cycle of latency in exchange for a shorter combinational path.
- **Pipeline Flushing:** Clearing the pipeline contents using the `clear_i` signal to reset the data flow state.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0      | 2026-07-20 | Foez Ahmed      | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Ratified                                               |
| 1.2      | 2026-08-15 | Foez Ahmed      | Added clear_i for pipeline flush capability            |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of https://github.com/adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/


module adn_common_pipeline #(
    parameter int DATA_WIDTH = 32  // Data bus width
) (
    // Clock and Reset
    input logic arst_ni,  // Active-low asynchronous reset
    input logic clk_i,    // Rising-edge clock

    input logic clear_i,  // Synchronous clear to flush pipeline

    // Input (Upstream) Interface
    input  logic [DATA_WIDTH-1:0] data_in_i,        // Input data
    input  logic                  data_in_valid_i,  // Input data valid
    output logic                  data_in_ready_o,  // Input ready (backpressure to upstream)

    // Output (Downstream) Interface
    output logic [DATA_WIDTH-1:0] data_out_o,        // Output data
    output logic                  data_out_valid_o,  // Output data valid
    input  logic                  data_out_ready_i   // Output ready (backpressure from downstream)
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] data_reg;  // Pipeline data register

  logic                  is_full;  // Pipeline full flag (valid data in data_reg)
  logic                  is_full_next;  // Next-state logic for is_full

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Input ready when pipeline not full, or when full and downstream is ready
  always_comb data_in_ready_o = is_full ? (data_out_ready_i | clear_i) : arst_ni;

  // Output data comes from pipeline register
  always_comb data_out_o = data_reg;

  // Output valid when pipeline is full
  always_comb data_out_valid_o = is_full & ~clear_i;

  // Next-state logic for pipeline full flag
  // Set when valid input accepted, clear when downstream ready and pipeline full
  always_comb is_full_next = data_in_valid_i ? '1 : (data_out_ready_i ? '0 : data_out_valid_o);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pipeline full flag with async active-low reset
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      is_full <= '0;
    end else if (clear_i) begin
      is_full <= data_in_valid_i;
    end else begin
      is_full <= is_full_next;
    end
  end

  // Data register: capture input when valid and ready (pipeline not full)
  always_ff @(posedge clk_i) begin
    if (arst_ni & data_in_valid_i & data_in_ready_o) begin
      data_reg <= data_in_i;
    end
  end

endmodule
