/*

### Purpose
The `adn_common_pmi_if` interface provides a standardized, transaction-level communication protocol for memory-mapped interactions within the adnsemicon ecosystem. It abstracts the underlying signal handshaking between masters and slaves, facilitating modular verification and design reuse through parameterized request and response structures.

### Use Case
This interface is primarily used to decouple the physical signal-level implementation of memory-mapped buses from the verification components (like UVM drivers/monitors) and RTL modules. By utilizing `msend`, `mrecv`, `ssend`, and `srecv` tasks, users can perform high-level read/write transactions without manually managing clock-cycle-accurate handshaking signals. It is ideal for:
- **Verification Environments:** Implementing bus functional models (BFMs) that interact with memory-mapped peripherals.
- **System-on-Chip (SoC) Integration:** Connecting IP blocks that require a standardized, lightweight interface for register access or memory-mapped communication.
- **Modular Design:** Allowing RTL designers to swap underlying bus protocols while keeping the transaction-level testbench code unchanged.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-13 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-13 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

interface adn_common_pmi_if #(
    parameter type req_t = logic, // Request structure type definition
    parameter type rsp_t = logic  // Response structure type definition
) (
    input logic arst_ni,          // Active-low asynchronous reset
    input logic clk_i             // System clock input
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  req_t req; // Request payload structure
  rsp_t rsp; // Response payload structure

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit   is_aligned; // Synchronization flag for transaction alignment

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MODPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Master interface: Drives requests and samples responses
  modport master(input arst_ni, input clk_i, output req, input rsp);

  // Slave interface: Samples requests and drives responses
  modport slave(input arst_ni, input clk_i, input req, output rsp);

  // Monitor interface: Passive observation of both request and response channels
  modport monitor(input arst_ni, input clk_i, input req, input rsp);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always @(posedge clk_i) begin
    is_aligned = '1;
    #1step;
    is_aligned = '0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////


  task automatic m_reset();
    req <= '0;
  endtask

  task automatic s_reset();
    rsp <= '0;
  endtask

  longint id_q_msend [$];
  longint n_id_msend;
  task automatic msend(input logic [31:0] addr, input logic we, input logic [31:0] wdata,
                       input logic [3:0] strb);
    longint t_id;
    t_id = n_id_msend;
    n_id_msend++;
    id_q_msend.push_back(t_id);
    forever @(id_q_msend.size()) if (id_q_msend[0] == t_id) break;

    if (arst_ni) begin
      wait (is_aligned);
      req.maddr  <= addr ;
      req.mwe    <= we   ;
      req.mwdata <= wdata;
      req.mstrb  <= strb ;
      req.mreq   <= '1   ;
      do @(posedge clk_i); while (arst_ni && rsp.mgnt !== 1);
      req.mreq <= '0;
    end

    id_q_msend.delete(0);
  endtask



  longint id_q_mrecv [$];
  longint n_id_mrecv;
  task automatic mrecv(output logic [31:0] rdata, output logic resp);
    longint t_id;
    t_id = n_id_mrecv;
    n_id_mrecv++;
    id_q_mrecv.push_back(t_id);
    forever @(id_q_mrecv.size()) if (id_q_mrecv[0] == t_id) break;

    if (arst_ni) begin
      do @(posedge clk_i); while (arst_ni && rsp.mack !== 1);
      rdata = rsp.mrdata;
      resp  = rsp.mresp;
    end

    id_q_mrecv.delete(0);
  endtask



  longint id_q_ssend [$];
  longint n_id_ssend;
  task automatic ssend(input logic [31:0] rdata, input logic resp);
    longint t_id;
    t_id = n_id_ssend;
    n_id_ssend++;
    id_q_ssend.push_back(t_id);
    forever @(id_q_ssend.size()) if (id_q_ssend[0] == t_id) break;

    if (arst_ni) begin
      wait (is_aligned);
      rsp.mrdata <= rdata;
      rsp.mresp  <= resp;
      rsp.mack   <= '1;
      @(posedge clk_i);
      rsp.mack <= '0;
    end

    id_q_ssend.delete(0);
  endtask



  longint id_q_srecv [$];
  longint n_id_srecv;
  task automatic srecv(output logic [31:0] addr, output logic we, output logic [31:0] wdata,
                       output logic [3:0] strb);
    longint t_id;
    t_id = n_id_srecv;
    n_id_srecv++;
    id_q_srecv.push_back(t_id);
    forever @(id_q_srecv.size()) if (id_q_srecv[0] == t_id) break;

    if (arst_ni) begin
      wait (is_aligned);
      rsp.mgnt <= '1;
      do @(posedge clk_i); while (arst_ni && rsp.mack !== 1);
      addr  = req.maddr;
      we    = req.mwe;
      wdata = req.mwdata;
      strb  = req.mstrb;
      rsp.mgnt <= '0;
    end

    id_q_srecv.delete(0);
  endtask


  task automatic mwrite(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb,
                        output logic resp);
    int dummy;
    fork
      msend(addr, '1, data, strb);
      mrecv(dummy, resp);
    join
  endtask


  task automatic mread(input logic [31:0] addr, output logic [31:0] data, output logic resp);
    fork
      msend(addr, '0, '0, '0);
      mrecv(data, resp);
    join
  endtask

endinterface
