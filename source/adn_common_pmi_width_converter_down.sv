/*

### Purpose
This module implements a width converter for the PMI (Parallel Memory Interface) protocol, designed to downsize the data bus width from a wider source interface to a narrower destination interface. It handles the serialization of wide write transactions and the deserialization of narrow read responses, ensuring data integrity across different bus widths.

### Use Case
This module is primarily used in SoC interconnects or memory controllers where a high-bandwidth master (e.g., a CPU or DMA engine) needs to communicate with a lower-bandwidth peripheral or memory slave. It acts as a bridge, breaking down large, wide-bus transactions into multiple smaller beats that the narrower slave interface can process, and reassembling the fragmented read responses back into the original wide format expected by the master.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0      | 2026-08-25 | Shuparna Haque  | Initial version                                        |
| 1.0      | 2026-08-25 | Shuparna Haque  | Stable release                                         |

Author : Shuparna Haque (sheikhshuparna3108@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pmi_width_converter_down #(
    // PARAMETERS
    parameter type s_req_t = logic, // Source request type
    parameter type s_rsp_t = logic, // Source response type
    parameter type m_req_t = logic, // Destination request type
    parameter type m_rsp_t = logic  // Destination response type
) (
    // PORTS
    input logic clk_i,   // System clock
    input logic arst_ni, // Active-low asynchronous reset

    input  s_req_t s_pmi_req_i, // Source PMI request input
    output s_rsp_t s_pmi_rsp_o, // Source PMI response output

    output m_req_t m_pmi_req_o, // Destination PMI request output
    input  m_rsp_t m_pmi_rsp_i  // Destination PMI response input
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////
    localparam int WIDE_DW   = $bits(s_pmi_req_i.mwdata);
    localparam int NARROW_DW = $bits(m_pmi_req_o.mwdata);
    localparam int RATIO     = WIDE_DW / NARROW_DW;
    localparam int BEAT_W    = (RATIO <= 1) ? 1 : $clog2(RATIO);
    localparam int NARROW_ADDR_LSB = $clog2(NARROW_DW / 8);
    

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
    logic [BEAT_W:0]    issue_cnt; // Counter for tracking serialized write beats
    logic [BEAT_W:0]    ack_cnt;   // Counter for tracking deserialized read beats
    logic [WIDE_DW-1:0] rdata_acc; // Accumulator for reassembling wide read data
    logic                mresp_acc; // Accumulator for capturing read response status

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
    // Request logic: Forward request only if within the serialization ratio
    assign m_pmi_req_o.mreq = s_pmi_req_i.mreq && (issue_cnt < RATIO);
  
    // Response logic: Signal completion to source only after all beats are processed
    assign s_pmi_rsp_o.mgnt = m_pmi_req_o.mreq && m_pmi_rsp_i.mgnt && (issue_cnt == RATIO - 1);
  
    // Address logic: Increment address based on narrow bus width per beat
    assign m_pmi_req_o.maddr = s_pmi_req_i.maddr | ({{($bits(s_pmi_req_i.maddr) - BEAT_W) {1'b0}}, issue_cnt[BEAT_W-1:0]} << NARROW_ADDR_LSB);
  
    assign m_pmi_req_o.mwe = s_pmi_req_i.mwe;
  
    // Data/Strobe logic: Slice wide data/strobe for narrow interface
    assign m_pmi_req_o.mwdata = s_pmi_req_i.mwe ? s_pmi_req_i.mwdata[issue_cnt*NARROW_DW+:NARROW_DW] : '0;
  
    assign m_pmi_req_o.mstrb = s_pmi_req_i.mwe ? s_pmi_req_i.mstrb[issue_cnt*(NARROW_DW/8)+:(NARROW_DW/8)] : '0;
  
    // Read response assembly
    assign s_pmi_rsp_o.mack   = m_pmi_rsp_i.mack && (ack_cnt == (RATIO - 1));
    assign s_pmi_rsp_o.mrdata = rdata_acc;
    assign s_pmi_rsp_o.mresp  = mresp_acc;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Write serialization state machine
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      issue_cnt <= '0;
    end else begin
      if (issue_cnt < RATIO) begin
        if (m_pmi_req_o.mreq && m_pmi_rsp_i.mgnt) begin
          issue_cnt <= issue_cnt + 1'b1;
        end
      end else begin
        if (ack_cnt == '0) begin
          issue_cnt <= '0;
        end
      end
    end
  end
 
  // Read deserialization state machine
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      ack_cnt   <= '0;
      rdata_acc <= '0;
      mresp_acc <= 1'b0;
    end else if (m_pmi_rsp_i.mack) begin
      if (ack_cnt == (RATIO - 1)) begin
        ack_cnt <= '0;
        rdata_acc[ack_cnt*NARROW_DW +: NARROW_DW] <= m_pmi_rsp_i.mrdata;
        mresp_acc <= mresp_acc | m_pmi_rsp_i.mresp;
      end else begin
        ack_cnt <= ack_cnt + 1'b1;
        rdata_acc[ack_cnt*NARROW_DW +: NARROW_DW] <= m_pmi_rsp_i.mrdata;
        mresp_acc <= mresp_acc | m_pmi_rsp_i.mresp;
      end
    end
  end
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    if ((WIDE_DW % NARROW_DW) != 0) begin
      $error("adn_common_pmi_width_converter_down: WIDE_DW must be an integer multiple of NARROW_DW");
    end
  end
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  initial begin
    if (RATIO > 8) begin
      $display("\033[1;33m%m RATIO\033[0m");
    end
  end
`endif  // SIMULATION

endmodule
