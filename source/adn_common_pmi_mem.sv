/*

### Purpose
This module provides a generic, latency-configurable memory interface wrapper based on the PMI (Processor Memory Interface) protocol. It facilitates read and write operations to a dual-port RAM while managing byte-level write strobes and synchronization latency.

### Use Case
This module is designed to act as a bridge between a high-level processor memory interface (PMI) and low-level physical memory primitives. It is primarily used in SoC designs where memory access latency needs to be tuned for timing closure or synchronization across clock domains. By abstracting the byte-strobe logic and providing a configurable pipeline depth, it allows designers to drop in a standard memory block without manually handling the complexities of read-modify-write cycles or synchronization stages.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-14 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-09-14 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pmi_mem #(
    parameter type pmi_req_t = logic, // PMI request structure type
    parameter type pmi_rsp_t = logic, // PMI response structure type
    parameter int  LATENCY   = 5      // Pipeline latency for memory access
) (
    input logic arst_ni, // Asynchronous active-low reset
    input logic clk_i,   // System clock

    input  pmi_req_t req_i, // PMI request input
    output pmi_rsp_t rsp_o  // PMI response output
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = $bits(type (req_i.maddr));
  localparam int DATA_WIDTH = $bits(type (req_i.mwdata));
  localparam int RSP_WIDTH  = $bits(type (rsp_o));
  localparam int DROP_BITS  = $clog2(DATA_WIDTH / 8);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH/8-1:0][7:0] wdata; // Write data bus with byte-level granularity
  logic [DATA_WIDTH/8-1:0][7:0] rdata; // Read data bus from memory
  logic [  ADDR_WIDTH-1:0]      addr;  // Memory address bus

  logic                         do_write; // Internal write enable signal

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Grant logic and response initialization
  always_comb rsp_o.mgnt = req_i.mreq;
  always_comb rsp_o.mresp = '0;

  // Write enable logic gated by request validity
  always_comb do_write = req_i.mwe & req_i.mreq;

  // Read-Modify-Write logic: Merge write data with existing data based on strobes
  always_comb begin
    foreach (wdata[i]) begin
      wdata[i] = req_i.mstrb[i] ? req_i.mwdata[i*8+:8] : rdata[i];
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pipeline synchronizer to manage access latency and clock domain crossing
  adn_common_synchronizer #(
      .WIDTH      (DATA_WIDTH + 1),
      .STAGES     (LATENCY),
      .RESET_VALUE('0)
  ) u_lat_pile (
      .clk_i  (clk_i),
      .arst_ni(arst_ni),
      .en_i   (1'b1),
      .data_i ({req_i.mreq, rdata}),
      .data_o ({rsp_o.mack, rsp_o.mrdata})
  );

  // Dual-port RAM primitive for data storage
  adn_common_dual_port_ram #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) u_mem (
      .clk_i    (clk_i),
      .wr_en_i  (do_write),
      .wr_addr_i(addr),
      .wr_data_i(wdata),
      .rd_addr_i(addr),
      .rd_data_o(rdata)
  );

endmodule
