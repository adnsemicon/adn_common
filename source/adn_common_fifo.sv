/*

### Purpose
This module implements a configurable, synchronous First-In-First-Out (FIFO) buffer. It provides a flexible mechanism for data buffering between modules with different throughput requirements, supporting both pipelined and non-pipelined modes to optimize for either latency or throughput.

### Use Case
This FIFO is ideal for:
- **Backpressure Handling:** Acting as a shock absorber when a consumer module cannot keep up with a producer.
- **Pipelined Data Paths:** Decoupling stages in a high-performance processing pipeline to prevent stalls.
- **Burst Data Management:** Storing bursts of data to be processed at a steady rate by downstream logic.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-07-27 | Annim Jannat    | Initial version                                        |
| 1.0      | 2026-07-28 | Annim Jannat    | Stable release                                         |
| 1.1      | 2026-08-02 | Foez Ahmed      | Ratified                                               |

Author : Annim Jannat (jannatannim@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_fifo #(
    parameter int DATA_WIDTH = 8,  // Width of the data bus in bits
    parameter int FIFO_SIZE  = 2,  // Log2 of the FIFO depth
    parameter bit PIPELINED  = 1   // Enable pipelined mode for higher throughput
) (
    input logic arst_ni,  // Asynchronous reset, active low
    input logic clk_i,    // System clock

    input  logic [DATA_WIDTH-1:0] data_in_i,        // Input data bus
    input  logic                  data_in_valid_i,  // Input data valid signal
    output logic                  data_in_ready_o,  // Input ready signal (backpressure)

    output logic [FIFO_SIZE:0] count_o,  // Current number of elements in FIFO

    output logic [DATA_WIDTH-1:0] data_out_o,        // Output data bus
    output logic                  data_out_valid_o,  // Output data valid signal
    input  logic                  data_out_ready_i   // Output ready signal from consumer
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int FIFO_DEPTH = 2 ** FIFO_SIZE;  // Calculated maximum capacity of the FIFO

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Write pointer: Tracks the next write address in the circular buffer
  logic [FIFO_SIZE-1:0] wr_ptr;  
  // Read pointer: Tracks the next read address in the circular buffer
  logic [FIFO_SIZE-1:0] rd_ptr;  

  // Input handshake: Valid and Ready are both high
  logic in_hs;  
  // Output handshake: Valid and Ready are both high
  logic out_hs;  

  // RAM output: Data retrieved from the internal memory array
  logic [DATA_WIDTH-1:0] mem_out;  

  // Bypass flag: High when FIFO is empty and data passes directly to output
  logic passing_through;  

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Handshake logic: high when both valid and ready are asserted
  always_comb in_hs = data_in_valid_i & data_in_ready_o;
  always_comb out_hs = data_out_valid_o & data_out_ready_i;

  // Output selection logic based on pipeline configuration
  always_comb data_out_o = passing_through ? data_in_i : mem_out;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Dual-port RAM instance for data storage
  adn_common_dual_port_ram #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(FIFO_SIZE)
  ) u_mem (
      .clk_i(clk_i),
      .wr_en_i(in_hs),
      .wr_addr_i(wr_ptr),
      .wr_data_i(data_in_i),
      .rd_addr_i(rd_ptr),
      .rd_data_o(mem_out)
  );

  // Handshake counter: Manages FIFO occupancy, pointers, and flow control logic
  adn_common_hs_counter #(
      .DEPTH    (FIFO_DEPTH),
      .PIPELINED(PIPELINED)
  ) u_hs_cntr (
      .clk_i            (clk_i),
      .arst_ni          (arst_ni),
      .data_in_valid_i  (data_in_valid_i),
      .data_in_ready_o  (data_in_ready_o),
      .count_o          (count_o),
      .passing_through_o(passing_through),
      .data_out_valid_o (data_out_valid_o),
      .data_out_ready_i (data_out_ready_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pointer update logic with asynchronous reset
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
    end else begin
      if (in_hs) wr_ptr <= wr_ptr + 1;
      if (out_hs) rd_ptr <= rd_ptr + 1;
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  initial begin
    if (DATA_WIDTH > 128) begin
      $display("\033[1;33m%m Significant big data width: %0d\033[0m", DATA_WIDTH);
    end

    if (FIFO_SIZE > 10) begin
      $display("\033[1;33m%m Significant Deep FIFO size: %0d\033[0m", FIFO_SIZE);
      $display("Consider a memory buffer instead");
    end
  end
`endif  // SIMULATION

endmodule
