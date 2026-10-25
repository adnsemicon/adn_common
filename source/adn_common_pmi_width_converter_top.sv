/*
### Purpose
This module serves as a top-level wrapper for a PMI (Parallel Memory Interface) width converter. It dynamically instantiates either an up-converter or a down-converter based on the relationship between the input and output data widths, or acts as a passthrough if the widths are identical.

### Use Case
This module is primarily used in SoC interconnects or memory subsystems where a master device with a specific data bus width needs to communicate with a slave device or memory controller that has a different data bus width. It abstracts the complexity of data serialization/deserialization, allowing seamless integration between mismatched PMI interfaces.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-30 | Motasim Faiyaz | Initial version                                        |
| 1.0      | 2026-08-30 | Motasim Faiyaz | Stable release                                         |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`include "pmi/typedef.svh"
module adn_common_pmi_width_converter_top #(
  parameter int ADDR_WIDTH     = 32, // Width of the address bus
  parameter int IN_DATA_WIDTH  = 32, // Width of the input data bus
  parameter int OUT_DATA_WIDTH = 64  // Width of the output data bus
) (
  input  logic                          clk,    // System clock
  input  logic                          arst_n, // Active-low asynchronous reset

  // Slave PMI Interface (Input)
  input  logic [ADDR_WIDTH-1:0]         s_maddr,  // Slave address
  input  logic                          s_mwe,    // Slave write enable
  input  logic [IN_DATA_WIDTH-1:0]      s_mwdata, // Slave write data
  input  logic [(IN_DATA_WIDTH/8)-1:0]  s_mstrb,  // Slave write strobe
  input  logic                          s_mreq,   // Slave request
  output logic                          s_mgnt,   // Slave grant
  output logic                          s_mack,   // Slave acknowledge
  output logic [IN_DATA_WIDTH-1:0]      s_mrdata, // Slave read data
  output logic                          s_mresp,  // Slave response

  // Master PMI Interface (Output)
  output logic [ADDR_WIDTH-1:0]         m_maddr,  // Master address
  output logic                          m_mwe,    // Master write enable
  output logic [OUT_DATA_WIDTH-1:0]     m_mwdata, // Master write data
  output logic [(OUT_DATA_WIDTH/8)-1:0] m_mstrb,  // Master write strobe
  output logic                          m_mreq,   // Master request
  input  logic                          m_mgnt,   // Master grant
  input  logic                          m_mack,   // Master acknowledge
  input  logic [OUT_DATA_WIDTH-1:0]     m_mrdata, // Master read data
  input  logic                          m_mresp   // Master response
);

 `PMI_T(s_pmi, ADDR_WIDTH, IN_DATA_WIDTH)
 `PMI_T(m_pmi, ADDR_WIDTH, OUT_DATA_WIDTH)

  // Internal PMI request/response structures
  s_pmi_req_t s_pmi_req_i;
  s_pmi_rsp_t s_pmi_rsp_i;
  m_pmi_req_t m_pmi_req_i;
  m_pmi_rsp_t m_pmi_rsp_i;

  // Mapping physical signals to internal PMI request structure
  assign s_pmi_req_i.maddr  = s_maddr;
  assign s_pmi_req_i.mwe    = s_mwe;
  assign s_pmi_req_i.mwdata = s_mwdata;
  assign s_pmi_req_i.mstrb  = s_mstrb;
  assign s_pmi_req_i.mreq   = s_mreq;

  // Mapping internal PMI response structure to physical signals
  assign s_mgnt   = s_pmi_rsp_i.mgnt;
  assign s_mack   = s_pmi_rsp_i.mack;
  assign s_mrdata = s_pmi_rsp_i.mrdata;
  assign s_mresp  = s_pmi_rsp_i.mresp;

  // Mapping internal PMI request structure to master physical signals
  assign m_maddr  = m_pmi_req_i.maddr;
  assign m_mwe    = m_pmi_req_i.mwe;
  assign m_mwdata = m_pmi_req_i.mwdata;
  assign m_mstrb  = m_pmi_req_i.mstrb;
  assign m_mreq   = m_pmi_req_i.mreq;

  // Mapping master physical signals to internal PMI response structure
  assign m_pmi_rsp_i.mgnt   = m_mgnt;
  assign m_pmi_rsp_i.mack   = m_mack;
  assign m_pmi_rsp_i.mrdata = m_mrdata;
  assign m_pmi_rsp_i.mresp  = m_mresp;

  // Generate block to select appropriate converter logic
  generate
    // Up-converter block for increasing data width
    if (OUT_DATA_WIDTH > IN_DATA_WIDTH) begin : g_up
      adn_common_pmi_width_converter_up #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .S_DATA_WIDTH (IN_DATA_WIDTH),
        .M_DATA_WIDTH (OUT_DATA_WIDTH),
        .s_req_t      (s_pmi_req_t),
        .s_rsp_t      (s_pmi_rsp_t),
        .m_req_t      (m_pmi_req_t),
        .m_rsp_t      (m_pmi_rsp_t)
      ) u_width_converter_up (
        .clk_i       (clk),
        .arst_ni     (arst_n),
        .s_pmi_req_i (s_pmi_req_i),
        .s_pmi_rsp_o (s_pmi_rsp_i),
        .m_pmi_req_o (m_pmi_req_i),
        .m_pmi_rsp_i (m_pmi_rsp_i)
      );
    end : g_up
    // Down-converter block for decreasing data width
    else if (OUT_DATA_WIDTH < IN_DATA_WIDTH) begin : g_down
      adn_common_pmi_width_converter_down #(
        .s_req_t (s_pmi_req_t),
        .s_rsp_t (s_pmi_rsp_t),
        .m_req_t (m_pmi_req_t),
        .m_rsp_t (m_pmi_rsp_t)
      ) u_width_converter_down (
        .clk_i       (clk),
        .arst_ni     (arst_n),
        .s_pmi_req_i (s_pmi_req_i),
        .s_pmi_rsp_o (s_pmi_rsp_i),
        .m_pmi_req_o (m_pmi_req_i),
        .m_pmi_rsp_i (m_pmi_rsp_i)
      );
    end : g_down
    // Passthrough logic when widths are equal
    else begin : g_passthrough
      assign m_pmi_req_i.maddr  = s_maddr;
      assign m_pmi_req_i.mwe    = s_mwe;
      assign m_pmi_req_i.mwdata = s_mwdata;
      assign m_pmi_req_i.mstrb  = s_mstrb;
      assign m_pmi_req_i.mreq   = s_mreq;
      assign s_pmi_rsp_i.mgnt   = m_mgnt;
      assign s_pmi_rsp_i.mack   = m_mack;
      assign s_pmi_rsp_i.mrdata = m_mrdata;
      assign s_pmi_rsp_i.mresp  = m_mresp;
    end : g_passthrough
  endgenerate

endmodule : adn_common_pmi_width_converter_top
