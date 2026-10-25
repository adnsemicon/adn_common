/*

### Purpose
This module implements a synchronous dual-port RAM with independent read and write clock domains. It supports configurable data width, address depth, and an optional output pipeline register to balance between latency and timing performance.

### Use Case
This module is designed for scenarios requiring asynchronous data buffering between two different clock domains (CDC). It is ideal for:
- **FIFO Buffers:** Acting as the storage core for asynchronous FIFOs where the producer and consumer operate at different frequencies.
- **Data Decoupling:** Buffering data streams in high-speed interfaces to prevent data loss during clock domain transitions.
- **Shared Memory:** Providing a bridge for data exchange between disparate processing units in a System-on-Chip (SoC) architecture.

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                        |
|----------|------------|---------------------|----------------------------------------------------|
| 0.1      | 2026-07-28 | Ahasan Ullah Khalid | Initial version                                    |
| 1.0      | 2026-07-28 | Ahasan Ullah Khalid | Stable release                                     |
| 1.1      | 2026-08-01 | Foez Ahmed          | Ratified                                           |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_dual_port_ram #(
    parameter int DATA_WIDTH = 32,  // Width of the data bus in bits
    parameter int ADDR_WIDTH = 8    // Width of the address bus (determines depth)
) (
    //Clock/Reset
    input logic clk_i,  // Write clock

    // Write Port Interface
    input logic                  wr_en_i,    // Write enable signal
    input logic [ADDR_WIDTH-1:0] wr_addr_i,  // Write address
    input logic [DATA_WIDTH-1:0] wr_data_i,  // Data to be written

    // Read Port Interface
    input  logic [ADDR_WIDTH-1:0] rd_addr_i,  // Read address
    output logic [DATA_WIDTH-1:0] rd_data_o   // Data read from memory
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  logic [DATA_WIDTH-1:0] mem_core[longint];
`else
  // Dual-Port memory matrix array: The physical storage element
  logic [DATA_WIDTH-1:0] mem_core[2**ADDR_WIDTH];
`endif

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  always @(posedge clk_i iff wr_en_i) mem_core[wr_addr_i] = #1step wr_data_i;
`else
  // Synchronous Write Channel (wr_clk_i Domain): Handles data storage into the memory array
  always_ff @(posedge clk_i iff wr_en_i) mem_core[wr_addr_i] <= wr_data_i;
`endif

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  always @(clk_i or rd_addr_i) rd_data_o <= mem_core[rd_addr_i];
`else
  // Asynchronous Read Channel: Instantly reflects changes on rd_addr_i when rd_en_i is high
  always_comb rd_data_o = mem_core[rd_addr_i];
`endif

endmodule
