/*

### Purpose
This module implements a Clock Domain Crossing (CDC) FIFO, designed to safely transfer data between two independent clock domains using Gray-coded pointers and multi-stage synchronizers to prevent metastability.

### Use Case
The `adn_common_cdc_fifo` is primarily used in digital systems where data must be passed between modules operating on different, asynchronous clock frequencies. By utilizing Gray-coded pointers, it ensures that only one bit changes at a time during pointer synchronization, effectively mitigating the risk of metastability that typically occurs when sampling signals across clock boundaries. It is ideal for streaming data interfaces, buffer management in high-speed communication protocols, and decoupling producer-consumer throughput variations.

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                        |
|----------|------------|---------------------|----------------------------------------------------|
| 0.1      | 2026-07-27 | Ahasan Ullah Khalid | Initial version                                    |
| 1.0      | 2026-07-29 | Ahasan Ullah Khalid | Stable release                                     |
| 1.1      | 2026-08-02 | Foez Ahmed          | Ratified                                           |
| 1.2      | 2026-08-19 | Ahasan Ullah Khalid | Stable release                                     |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_cdc_fifo #(
    parameter int DATA_WIDTH  = 8,  // Width of the data bus
    parameter int FIFO_SIZE   = 2,  // Log2 of the FIFO depth
    parameter int SYNC_STAGES = 2   // Number of synchronization stages
) (
    // Data input bus
    input  logic [DATA_WIDTH-1:0] data_in_i,
    // Valid signal for input data
    input  logic                  data_in_valid_i,
    // Ready signal for input data
    output logic                  data_in_ready_o,
    // Asynchronous reset, active low (input domain)
    input  logic                  data_in_arst_ni,
    // Clock signal for the input domain
    input  logic                  data_in_clk_i,
    // Current occupancy count (input domain)
    output logic [   FIFO_SIZE:0] data_in_count_o,

    // Data output bus
    output logic [DATA_WIDTH-1:0] data_out_o,
    // Valid signal for output data
    output logic                  data_out_valid_o,
    // Ready signal for output data
    input  logic                  data_out_ready_i,
    // Asynchronous reset, active low (output domain)
    input  logic                  data_out_arst_ni,
    // Clock signal for the output domain
    input  logic                  data_out_clk_i,
    // Current occupancy count (output domain)
    output logic [   FIFO_SIZE:0] data_out_count_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic common_arst_n;  // Combined asynchronous reset for both domains

  logic [FIFO_SIZE:0] wr_addr;  // Write pointer (binary)
  logic [FIFO_SIZE:0] rd_addr;  // Read pointer (binary)

  logic [FIFO_SIZE:0] wr_addr_next;  // Write pointer next (binary)
  logic [FIFO_SIZE:0] rd_addr_next;  // Read pointer next (binary)

  logic [FIFO_SIZE:0] wr_addr_;  // Synchronized write pointer (binary, output domain)
  logic [FIFO_SIZE:0] rd_addr_;  // Synchronized read pointer (binary, input domain)

  logic [FIFO_SIZE:0] wpgi;  // Write pointer (Gray, input domain)
  logic [FIFO_SIZE:0] wpgo;  // Write pointer (Gray, output domain)
  logic [FIFO_SIZE:0] rpgi;  // Read pointer (Gray, output domain)
  logic [FIFO_SIZE:0] rpgo;  // Read pointer (Gray, input domain)

  logic [FIFO_SIZE:0] wr_ptr_pass;  // Intermediate write pointer for synchronization
  logic [FIFO_SIZE:0] rd_ptr_pass;  // Intermediate read pointer for synchronization

  logic in_hs;  // Input handshake signal
  logic out_hs;  // Output handshake signal

  logic full_ic;  // FIFO full status (input domain)
  logic empty_oc;  // FIFO empty status (output domain)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb common_arst_n = data_in_arst_ni & data_out_arst_ni;

  always_comb
    full_ic = (wr_addr[FIFO_SIZE-1:0] == rd_addr_[FIFO_SIZE-1:0])
                    & (wr_addr[FIFO_SIZE] != rd_addr_[FIFO_SIZE]);

  always_comb empty_oc = (wr_addr_ == rd_addr);

  always_comb data_in_ready_o = ~full_ic;
  always_comb data_out_valid_o = ~empty_oc;

  always_comb in_hs = data_in_valid_i & data_in_ready_o;
  always_comb out_hs = data_out_valid_o & data_out_ready_i;

  always_comb data_in_count_o = wr_addr - rd_addr_;
  always_comb data_out_count_o = wr_addr_ - rd_addr;

  always_comb wr_addr_next = wr_addr + 1;
  always_comb rd_addr_next = rd_addr + 1;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Dual-port RAM for data storage
  adn_common_dual_port_ram #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(FIFO_SIZE)
  ) u_mem (
      .clk_i(data_in_clk_i),
      .wr_en_i(in_hs),
      .wr_addr_i(wr_addr[FIFO_SIZE-1:0]),
      .wr_data_i(data_in_i),
      .rd_addr_i(rd_addr[FIFO_SIZE-1:0]),
      .rd_data_o(data_out_o)
  );

  // Binary to Gray converters for pointers
  adn_common_bin_to_gray #(
      .WIDTH(FIFO_SIZE + 1)
  ) b2g_w (
      .bin_i (wr_addr_next),
      .gray_o(wpgi)
  );

  adn_common_bin_to_gray #(
      .WIDTH(FIFO_SIZE + 1)
  ) b2g_r (
      .bin_i (rd_addr_next),
      .gray_o(rpgi)
  );

  // Gray to Binary converters for pointers
  adn_common_gray_to_bin #(
      .WIDTH(FIFO_SIZE + 1)
  ) g2b_wi (
      .gray_i(wr_ptr_pass),
      .bin_o (wr_addr)
  );

  adn_common_gray_to_bin #(
      .WIDTH(FIFO_SIZE + 1)
  ) g2b_wo (
      .gray_i(wpgo),
      .bin_o (wr_addr_)
  );

  adn_common_gray_to_bin #(
      .WIDTH(FIFO_SIZE + 1)
  ) g2b_ri (
      .gray_i(rpgo),
      .bin_o (rd_addr_)
  );

  adn_common_gray_to_bin #(
      .WIDTH(FIFO_SIZE + 1)
  ) g2b_ro (
      .gray_i(rd_ptr_pass),
      .bin_o (rd_addr)
  );

  // Multi-stage synchronizers for CDC
  adn_common_synchronizer #(
      .WIDTH(FIFO_SIZE + 1),
      .STAGES(1),
      .RESET_VALUE('0)
  ) wr_ptr_ic (
      .clk_i(data_in_clk_i),
      .arst_ni(common_arst_n),
      .en_i(in_hs),
      .data_i(wpgi),
      .data_o(wr_ptr_pass)
  );

  adn_common_synchronizer #(
      .WIDTH(FIFO_SIZE + 1),
      .STAGES(SYNC_STAGES),
      .RESET_VALUE('0)
  ) wr_ptr_oc (
      .clk_i(data_out_clk_i),
      .arst_ni(common_arst_n),
      .en_i('1),
      .data_i(wr_ptr_pass),
      .data_o(wpgo)
  );

  adn_common_synchronizer #(
      .WIDTH(FIFO_SIZE + 1),
      .STAGES(1),
      .RESET_VALUE('0)
  ) rd_ptr_oc (
      .clk_i(data_out_clk_i),
      .arst_ni(common_arst_n),
      .en_i(out_hs),
      .data_i(rpgi),
      .data_o(rd_ptr_pass)
  );

  adn_common_synchronizer #(
      .WIDTH(FIFO_SIZE + 1),
      .STAGES(SYNC_STAGES),
      .RESET_VALUE('0)
  ) rd_ptr_ic (
      .clk_i(data_in_clk_i),
      .arst_ni(common_arst_n),
      .en_i('1),
      .data_i(rd_ptr_pass),
      .data_o(rpgo)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  initial begin
    if (DATA_WIDTH > 2) begin
      $display("\033[1;33m%m DATA_WIDTH\033[0m");
    end
  end
`endif  // SIMULATION

endmodule
