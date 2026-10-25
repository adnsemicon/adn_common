/*
| TEST CASE | DATE       | AUTHOR  | DESCRIPTION                                                       |
|-----------|------------|---------|-------------------------------------------------------------------|
| TC_001    | 2026-08-03 | Motasim | Idle: no requests -> gnt_o=0                                      |
| TC_002    | 2026-08-03 | Motasim | Single-bit walk: each req_i[i] alone grants gnt_o[i]              |
| TC_003    | 2026-08-03 | Motasim | Priority resolution: multiple requesters, lowest index wins       |
| TC_004    | 2026-08-03 | Motasim | allow_req_i gating: gnt_o must be 0 whenever allow_req_i is low   |
| TC_005    | 2026-08-03 | Motasim | Random regression vs. reference model (self-checking)             |
 
| REVISION | DATE       | AUTHOR  | DESCRIPTION        |
|----------|------------|---------|--------------------|
| 0.1      | 2026-08-03 | Motasim | Initial version    |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/


module adn_common_fixed_priority_arbiter_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int NUM_REQ = 8;
  localparam int RAND_ITER = 100;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic  [NUM_REQ-1:0] req;
  logic                allow;
  logic  [NUM_REQ-1:0] gnt;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // scratch draws used by TC_005's random regression loop
  logic  [NUM_REQ-1:0] rand_req;
  logic                rand_allow;

  // capture testcase labels exactly when a check fails
  string               failed_labels[$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLASSES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_fixed_priority_arbiter #(
      .NUM_REQ(NUM_REQ),
      .HIGH_INDEX_PRIORITY(0)
  ) dut (
      .req_i      (req),
      .allow_req_i(allow),
      .gnt_o      (gnt)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Reference model: lowest set bit wins, gated by allow.
  function automatic logic [NUM_REQ-1:0] predict_gnt(input logic [NUM_REQ-1:0] r,
                                                     input logic allow_v);
    logic found;
    predict_gnt = '0;
    if (!allow_v) return predict_gnt;
    found = 1'b0;
    for (int i = 0; i < NUM_REQ; i++) begin
      if (r[i] && !found) begin
        predict_gnt[i] = 1'b1;
        found          = 1'b1;
      end
    end
  endfunction

  // Drive stimulus and check DUT output against the reference model.
  task automatic check(input logic [NUM_REQ-1:0] r, input logic allow_v, input string label);
    logic [NUM_REQ-1:0] exp_gnt;
    bit                 pass;

    req   = r;
    allow = allow_v;
    #1;

    exp_gnt = predict_gnt(r, allow_v);
    pass    = (gnt === exp_gnt);

    if (pass) begin
      $display("[PASS][%0t] %-40s exp=%0b act=%0b req=%0b allow=%0b", $realtime, label, exp_gnt,
               gnt, r, allow_v);
      note_case(1'b1);
    end else begin
      $display("[FAIL][%0t] %-40s exp=%0b act=%0b req=%0b allow=%0b", $realtime, label, exp_gnt,
               gnt, r, allow_v);
      failed_labels.push_back(label);
      note_case(1'b0);
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial

    // TC_001 : idle
    check('0, 1'b1, "TC_001 idle");

    // TC_002 : single-bit walk
    for (int i = 0; i < NUM_REQ; i++) begin
      check(logic'(1 << i), 1'b1, $sformatf("TC_002.%0d single req[%0d]", i, i));
    end

    // TC_003 : priority resolution
    check(8'b1111_1111, 1'b1, "TC_003.0 all req -> bit0 wins");
    check(8'b0010_0100, 1'b1, "TC_003.1 req={5,2} -> bit2 wins");
    check(8'b1000_0010, 1'b1, "TC_003.2 req={7,1} -> bit1 wins");

    // TC_004 : allow_req_i gating
    // NOTE: allow_req_i is documented as a "Global enable signal to permit
    // granting" but is not wired into the DUT. This test case is expected
    // to FAIL against the current RTL until that's fixed.
    check(8'b0000_0001, 1'b0, "TC_004.0 allow=0, req active -> gnt must be 0");
    check(8'b1111_1111, 1'b0, "TC_004.1 allow=0, all req active -> gnt must be 0");
    check(8'b0000_0001, 1'b1, "TC_004.2 allow=1, req active -> gnt fires normally");

    // TC_005 : random regression
    for (int i = 0; i < RAND_ITER; i++) begin
      rand_req   = $urandom;
      rand_allow = $urandom_range(0, 9) != 0;  // allow low ~10% of the time
      check(rand_req, rand_allow, $sformatf(
            "TC_005.%0d random req=%0b allow=%0b", i, rand_req, rand_allow));
    end

    $finish;

  end

  final begin
    $display("\033[7;38m######## FAILED TESTCASE LIST ########\033[0m");
    if (failed_labels.size() == 0) begin
      $display("NONE");
    end else begin
      foreach (failed_labels[i]) begin
        $display("- %s", failed_labels[i]);
      end
    end
  end

endmodule
