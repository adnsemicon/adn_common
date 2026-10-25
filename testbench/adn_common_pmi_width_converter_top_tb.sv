/*

| TEST CASE | DATE       | AUTHOR             | DESCRIPTION                                                          |
|-----------|------------|--------------------|----------------------------------------------------------------------|
| TC_001    | 2026-09-07 | Shuparna Haque     | Up-converter (32->64) single write                                   |
| TC_002    | 2026-09-07 | Shuparna Haque     | Down-converter (64->32) single read                                  |
| TC_003    | 2026-09-08 | Shuparna Haque     | Down-converter (64->32) single write, per-beat checks                |
| TC_004    | 2026-09-08 | Shuparna Haque     | Up-converter (32->64) single read                                    |
| TC_005    | 2026-09-08 | Shykul ISlam Siam  | Passthrough (32->32) write, equal-width path                         |
| TC_006    | 2026-09-08 | Shykul ISlam Siam  | Down-converter sequential writes with an idle cycle                  |
| TC_007    | 2026-09-08 | Shykul ISlam Siam  | Reset asserted mid-burst on down-converter, checks clean recovery    |
| TC_008    | 2026-09-08 | Shuparna Haque     | Passthrough (32->32) read, equal-width path                          |
| TC_009    | 2026-09-08 | Shuparna Haque     | Reset asserted mid-burst on down-converter, checks clean recovery    |


| REVISION | DATE       | AUTHOR             | DESCRIPTION                                                           |
|----------|------------|--------------------|-----------------------------------------------------------------------|
| 1.0      | 2026-09-07 | Shuparna Haque     | Initial release                                                       |
| 1.1      | 2026-09-08 | Shykul ISlam Siam  | Fixed down-read handshake, added TC_005-007                           |
| 1.2      | 2026-09-08 | Shuparna Haque     | Added TC_008, TC_009, fixed reset handling                            |



Author : Shuparna Haque (sheikhshuparna3108@gmail.com) & Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pmi_width_converter_top_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH = 32;
  localparam int WIDTH_NARROW = 32;
  localparam int WIDTH_WIDE = 64;
  localparam int RATIO_64_32 = WIDTH_WIDE / WIDTH_NARROW;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic                        clk;
  logic                        arst_n;

  // ---- dut_up : IN=32 (narrow, s side); OUT=64 (wide, m side) ----
  logic [      ADDR_WIDTH-1:0] up_s_maddr;
  logic                        up_s_mwe;
  logic [    WIDTH_NARROW-1:0] up_s_mwdata;
  logic [(WIDTH_NARROW/8)-1:0] up_s_mstrb;
  logic                        up_s_mreq;
  logic                        up_s_mgnt;
  logic                        up_s_mack;
  logic [    WIDTH_NARROW-1:0] up_s_mrdata;
  logic                        up_s_mresp;

  logic [      ADDR_WIDTH-1:0] up_m_maddr;
  logic                        up_m_mwe;
  logic [      WIDTH_WIDE-1:0] up_m_mwdata;
  logic [  (WIDTH_WIDE/8)-1:0] up_m_mstrb;
  logic                        up_m_mreq;
  logic                        up_m_mgnt;
  logic                        up_m_mack;
  logic [      WIDTH_WIDE-1:0] up_m_mrdata;
  logic                        up_m_mresp;

  // ---- dut_down : IN=64 (wide, s side); OUT=32 (narrow, m side) ----
  logic [      ADDR_WIDTH-1:0] dn_s_maddr;
  logic                        dn_s_mwe;
  logic [      WIDTH_WIDE-1:0] dn_s_mwdata;
  logic [  (WIDTH_WIDE/8)-1:0] dn_s_mstrb;
  logic                        dn_s_mreq;
  logic                        dn_s_mgnt;
  logic                        dn_s_mack;
  logic [      WIDTH_WIDE-1:0] dn_s_mrdata;
  logic                        dn_s_mresp;

  logic [      ADDR_WIDTH-1:0] dn_m_maddr;
  logic                        dn_m_mwe;
  logic [    WIDTH_NARROW-1:0] dn_m_mwdata;
  logic [(WIDTH_NARROW/8)-1:0] dn_m_mstrb;
  logic                        dn_m_mreq;
  logic                        dn_m_mgnt;
  logic                        dn_m_mack;
  logic [    WIDTH_NARROW-1:0] dn_m_mrdata;
  logic                        dn_m_mresp;

  // ---- dut_eq : IN=32 ; OUT=32 (passthrough / equal-width path) ----
  logic [      ADDR_WIDTH-1:0] eq_s_maddr;
  logic                        eq_s_mwe;
  logic [    WIDTH_NARROW-1:0] eq_s_mwdata;
  logic [(WIDTH_NARROW/8)-1:0] eq_s_mstrb;
  logic                        eq_s_mreq;
  logic                        eq_s_mgnt;
  logic                        eq_s_mack;
  logic [    WIDTH_NARROW-1:0] eq_s_mrdata;
  logic                        eq_s_mresp;

  logic [      ADDR_WIDTH-1:0] eq_m_maddr;
  logic                        eq_m_mwe;
  logic [    WIDTH_NARROW-1:0] eq_m_mwdata;
  logic [(WIDTH_NARROW/8)-1:0] eq_m_mstrb;
  logic                        eq_m_mreq;
  logic                        eq_m_mgnt;
  logic                        eq_m_mack;
  logic [    WIDTH_NARROW-1:0] eq_m_mrdata;
  logic                        eq_m_mresp;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Wide (64b) slave BFM for dut_up's downstream side
  assign up_m_mgnt   = up_m_mreq;
  assign up_m_mack   = up_m_mreq && up_m_mgnt;
  assign up_m_mresp  = 1'b0;
  assign up_m_mrdata = up_m_mwe ? '0 : {32'hCAFE_0000, up_m_maddr};

  // Narrow (32b) slave BFM for dut_down's downstream side
  assign dn_m_mgnt   = dn_m_mreq;
  assign dn_m_mack   = dn_m_mreq && dn_m_mgnt;
  assign dn_m_mresp  = 1'b0;
  assign dn_m_mrdata = dn_m_mwe ? '0 : dn_m_maddr;

  // 32b slave BFM for dut_eq's downstream side (passthrough)
  assign eq_m_mgnt   = eq_m_mreq;
  assign eq_m_mack   = eq_m_mreq && eq_m_mgnt;
  assign eq_m_mresp  = 1'b0;
  assign eq_m_mrdata = eq_m_mwe ? '0 : eq_m_maddr;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_pmi_width_converter_top #(
      .ADDR_WIDTH    (ADDR_WIDTH),
      .IN_DATA_WIDTH (WIDTH_NARROW),
      .OUT_DATA_WIDTH(WIDTH_WIDE)
  ) dut_up (
      .clk     (clk),
      .arst_n  (arst_n),
      .s_maddr (up_s_maddr),
      .s_mwe   (up_s_mwe),
      .s_mwdata(up_s_mwdata),
      .s_mstrb (up_s_mstrb),
      .s_mreq  (up_s_mreq),
      .s_mgnt  (up_s_mgnt),
      .s_mack  (up_s_mack),
      .s_mrdata(up_s_mrdata),
      .s_mresp (up_s_mresp),
      .m_maddr (up_m_maddr),
      .m_mwe   (up_m_mwe),
      .m_mwdata(up_m_mwdata),
      .m_mstrb (up_m_mstrb),
      .m_mreq  (up_m_mreq),
      .m_mgnt  (up_m_mgnt),
      .m_mack  (up_m_mack),
      .m_mrdata(up_m_mrdata),
      .m_mresp (up_m_mresp)
  );

  adn_common_pmi_width_converter_top #(
      .ADDR_WIDTH    (ADDR_WIDTH),
      .IN_DATA_WIDTH (WIDTH_WIDE),
      .OUT_DATA_WIDTH(WIDTH_NARROW)
  ) dut_down (
      .clk     (clk),
      .arst_n  (arst_n),
      .s_maddr (dn_s_maddr),
      .s_mwe   (dn_s_mwe),
      .s_mwdata(dn_s_mwdata),
      .s_mstrb (dn_s_mstrb),
      .s_mreq  (dn_s_mreq),
      .s_mgnt  (dn_s_mgnt),
      .s_mack  (dn_s_mack),
      .s_mrdata(dn_s_mrdata),
      .s_mresp (dn_s_mresp),
      .m_maddr (dn_m_maddr),
      .m_mwe   (dn_m_mwe),
      .m_mwdata(dn_m_mwdata),
      .m_mstrb (dn_m_mstrb),
      .m_mreq  (dn_m_mreq),
      .m_mgnt  (dn_m_mgnt),
      .m_mack  (dn_m_mack),
      .m_mrdata(dn_m_mrdata),
      .m_mresp (dn_m_mresp)
  );

  adn_common_pmi_width_converter_top #(
      .ADDR_WIDTH    (ADDR_WIDTH),
      .IN_DATA_WIDTH (WIDTH_NARROW),
      .OUT_DATA_WIDTH(WIDTH_NARROW)
  ) dut_eq (
      .clk     (clk),
      .arst_n  (arst_n),
      .s_maddr (eq_s_maddr),
      .s_mwe   (eq_s_mwe),
      .s_mwdata(eq_s_mwdata),
      .s_mstrb (eq_s_mstrb),
      .s_mreq  (eq_s_mreq),
      .s_mgnt  (eq_s_mgnt),
      .s_mack  (eq_s_mack),
      .s_mrdata(eq_s_mrdata),
      .s_mresp (eq_s_mresp),
      .m_maddr (eq_m_maddr),
      .m_mwe   (eq_m_mwe),
      .m_mwdata(eq_m_mwdata),
      .m_mstrb (eq_m_mstrb),
      .m_mreq  (eq_m_mreq),
      .m_mgnt  (eq_m_mgnt),
      .m_mack  (eq_m_mack),
      .m_mrdata(eq_m_mrdata),
      .m_mresp (eq_m_mresp)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic check_result(input string check_name, input bit pass);
    note_case(pass);
    if (!pass) $display("FAIL [%s] time=%0t", check_name, $time);
  endtask

  task automatic apply_reset();
    arst_n = 0;

    up_s_maddr = '0;
    up_s_mwe = 0;
    up_s_mwdata = '0;
    up_s_mstrb = '0;
    up_s_mreq = 0;
    dn_s_maddr = '0;
    dn_s_mwe = 0;
    dn_s_mwdata = '0;
    dn_s_mstrb = '0;
    dn_s_mreq = 0;
    eq_s_maddr = '0;
    eq_s_mwe = 0;
    eq_s_mwdata = '0;
    eq_s_mstrb = '0;
    eq_s_mreq = 0;

    #20;
    arst_n = 1;
  endtask

  task automatic check_up_write(input logic [ADDR_WIDTH-1:0] addr,
                                input logic [WIDTH_NARROW-1:0] data,
                                input logic [(WIDTH_NARROW/8)-1:0] strb);
    @(negedge clk);
    up_s_maddr = addr;
    up_s_mwe = 1'b1;
    up_s_mwdata = data;
    up_s_mstrb = strb;
    up_s_mreq = 1'b1;
    wait (up_s_mgnt === 1'b1);

    check_result("TC_001 up write data",
                 up_m_mwdata === {{(WIDTH_WIDE - WIDTH_NARROW) {1'b0}}, data});
    check_result("TC_001 up write strobe",
                 up_m_mstrb === {{((WIDTH_WIDE / 8) - (WIDTH_NARROW / 8)) {1'b0}}, strb});

    @(negedge clk);
    up_s_mwe  = 0;
    up_s_mreq = 0;
  endtask

  task automatic check_down_read(input logic [ADDR_WIDTH-1:0] addr);
    logic [WIDTH_WIDE-1:0] expected;
    for (int beat = 0; beat < RATIO_64_32; beat++)
      expected[beat*WIDTH_NARROW+:WIDTH_NARROW] = addr + beat * (WIDTH_NARROW / 8);

    @(negedge clk);
    dn_s_maddr = addr;
    dn_s_mwe   = 1'b0;
    dn_s_mreq  = 1'b1;
    repeat (RATIO_64_32 - 1) @(posedge clk);
    @(negedge clk);
    check_result("TC_002 down read source grant", dn_s_mgnt === 1'b1);
    @(posedge clk);
    @(negedge clk);

    if (dn_s_mrdata !== expected)
      $display("TC_002 details expected=%h actual=%h", expected, dn_s_mrdata);
    check_result("TC_002 down read data", dn_s_mrdata === expected);

    @(negedge clk);
    dn_s_mreq = 0;
  endtask

  task automatic check_down_write(input logic [ADDR_WIDTH-1:0] addr,
                                  input logic [WIDTH_WIDE-1:0] data,
                                  input logic [(WIDTH_WIDE/8)-1:0] strb);
    @(negedge clk);
    dn_s_maddr = addr;
    dn_s_mwe = 1'b1;
    dn_s_mwdata = data;
    dn_s_mstrb = strb;
    dn_s_mreq = 1'b1;

    for (int beat = 0; beat < RATIO_64_32; beat++) begin
      wait (dn_m_mgnt === 1'b1);
      check_result($sformatf("TC_003 down write beat %0d address", beat),
                   dn_m_maddr === (addr + beat * (WIDTH_NARROW / 8)));
      check_result($sformatf("TC_003 down write beat %0d data", beat),
                   dn_m_mwdata === data[beat*WIDTH_NARROW+:WIDTH_NARROW]);
      check_result($sformatf("TC_003 down write beat %0d strobe", beat),
                   dn_m_mstrb === strb[beat*(WIDTH_NARROW/8)+:(WIDTH_NARROW/8)]);
      check_result($sformatf("TC_003 down write beat %0d acknowledge", beat), dn_m_mack === 1'b1);
      if (beat == RATIO_64_32 - 1)
        check_result("TC_003 down write source grant", dn_s_mgnt === 1'b1);
      @(negedge clk);
    end

    dn_s_mwe  = 0;
    dn_s_mreq = 0;
  endtask

  task automatic check_up_read(input logic [ADDR_WIDTH-1:0] addr);
    logic [WIDTH_NARROW-1:0] expected;
    expected = addr;

    @(negedge clk);
    up_s_maddr = addr;
    up_s_mwe   = 1'b0;
    up_s_mreq  = 1'b1;
    wait (up_s_mgnt === 1'b1);
    wait (up_s_mack === 1'b1);

    check_result("TC_004 up read data", up_s_mrdata === expected);

    @(negedge clk);
    up_s_mreq = 0;
  endtask

  task automatic check_eq_passthrough(input logic [ADDR_WIDTH-1:0] addr,
                                      input logic [WIDTH_NARROW-1:0] data,
                                      input logic [(WIDTH_NARROW/8)-1:0] strb);
    @(negedge clk);
    eq_s_maddr = addr;
    eq_s_mwe = 1'b1;
    eq_s_mwdata = data;
    eq_s_mstrb = strb;
    eq_s_mreq = 1'b1;
    wait (eq_s_mgnt === 1'b1);

    check_result("TC_005 passthrough address", eq_m_maddr === addr);
    check_result("TC_005 passthrough write data", eq_m_mwdata === data);
    check_result("TC_005 passthrough strobe", eq_m_mstrb === strb);
    check_result("TC_005 passthrough write enable", eq_m_mwe === 1'b1);

    @(negedge clk);
    eq_s_mwe  = 0;
    eq_s_mreq = 0;
  endtask

  // Two down-converter writes separated by an idle cycle.
  task automatic check_down_write_burst();
    logic [ADDR_WIDTH-1:0] addr0 = 32'h0000_0400, addr1 = 32'h0000_0410;
    logic [WIDTH_WIDE-1:0] data0 = 64'h1111_2222_3333_4444, data1 = 64'h5555_6666_7777_8888;

    @(negedge clk);
    dn_s_maddr = addr0;
    dn_s_mwe = 1'b1;
    dn_s_mwdata = data0;
    dn_s_mstrb = 8'hFF;
    dn_s_mreq = 1'b1;
    for (int beat = 0; beat < RATIO_64_32; beat++) begin
      wait (dn_m_mgnt === 1'b1);
      check_result($sformatf("TC_006 xact0 beat %0d data", beat),
                   dn_m_mwdata === data0[beat*WIDTH_NARROW+:WIDTH_NARROW]);
      if (beat == RATIO_64_32 - 1) check_result("TC_006 xact0 source grant", dn_s_mgnt === 1'b1);
      @(negedge clk);
    end

    dn_s_mreq = 0;
    @(negedge clk);

    dn_s_maddr  = addr1;
    dn_s_mwdata = data1;
    dn_s_mreq   = 1'b1;
    for (int beat = 0; beat < RATIO_64_32; beat++) begin
      wait (dn_m_mgnt === 1'b1);
      check_result($sformatf("TC_006 xact1 beat %0d data", beat),
                   dn_m_mwdata === data1[beat*WIDTH_NARROW+:WIDTH_NARROW]);
      if (beat == RATIO_64_32 - 1) check_result("TC_006 xact1 source grant", dn_s_mgnt === 1'b1);
      @(negedge clk);
    end

    dn_s_mwe  = 0;
    dn_s_mreq = 0;
  endtask

  task automatic check_eq_read(input logic [ADDR_WIDTH-1:0] addr);
    logic [WIDTH_NARROW-1:0] expected;
    expected = addr;

    @(negedge clk);
    eq_s_maddr = addr;
    eq_s_mwe   = 1'b0;
    eq_s_mreq  = 1'b1;
    wait (eq_s_mgnt === 1'b1);
    wait (eq_s_mack === 1'b1);

    check_result("TC_008 passthrough read data", eq_s_mrdata === expected);

    @(negedge clk);
    eq_s_mreq = 0;
  endtask

  task automatic check_reset_mid_burst();
    @(negedge clk);
    dn_s_maddr = 32'h0000_0500;
    dn_s_mwe = 1'b1;
    dn_s_mwdata = 64'hDEAD_DEAD_BEEF_BEEF;
    dn_s_mstrb = 8'hFF;
    dn_s_mreq = 1'b1;
    wait (dn_m_mgnt === 1'b1);
    @(posedge clk);  // let beat 0 actually latch (issue_cnt -> 1) before pulling reset,
                     // since dn_m_mgnt is combinational and resolves before any clock edge

    apply_reset();

    check_result("TC_007 mreq clears after reset", dn_s_mreq === 1'b0);
    check_result("TC_007 mgnt clears after reset", dn_m_mgnt === 1'b0);
    check_down_write(32'h0000_0510, 64'hCAFE_CAFE_F00D_F00D, 8'hFF);
  endtask
  
  task automatic check_reset_mid_read();
    @(negedge clk);
    dn_s_maddr = 32'h0000_0B00;
    dn_s_mwe   = 1'b0;
    dn_s_mreq  = 1'b1;
    wait (dn_m_mack === 1'b1);
    @(posedge clk);

    apply_reset();

    check_result("TC_09 mreq clears after reset", dn_s_mreq === 1'b0);
    check_result("TC_09 mack clears after reset", dn_m_mack === 1'b0);
    check_down_read(32'h0000_0B10);
  endtask
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial clk = 0;
  always #5 clk = ~clk;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin  // main initial
    apply_reset();

    case (test_name)
      "TC_001": check_up_write(32'h0000_0010, 32'hDEAD_BEEF, 4'hF);
      "TC_002": check_down_read(32'h0000_0200);
      "TC_003": check_down_write(32'h0000_0100, 64'hDEAD_BEEF_CAFE_F00D, 8'hFF);
      "TC_004": check_up_read(32'h0000_0040);
      "TC_005": check_eq_passthrough(32'h0000_0300, 32'hABCD_1234, 4'hF);
      "TC_006": check_down_write_burst();
      "TC_007": check_reset_mid_burst();
      "TC_008": check_eq_read(32'h0000_0300);
      "TC_009": check_reset_mid_read();
      default: begin
        check_up_write(32'h0000_0010, 32'hDEAD_BEEF, 4'hF);
        check_down_read(32'h0000_0200);
        check_down_write(32'h0000_0100, 64'hDEAD_BEEF_CAFE_F00D, 8'hFF);
        check_up_read(32'h0000_0040);
        check_eq_passthrough(32'h0000_0300, 32'hABCD_1234, 4'hF);
        check_down_write_burst();
        check_reset_mid_burst();
      end
    endcase
    $finish;

  end

endmodule
