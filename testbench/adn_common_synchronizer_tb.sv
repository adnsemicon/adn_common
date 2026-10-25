/*

| TEST CASE | DATE       | AUTHOR            | DESCRIPTION                                           |
|-----------|------------|-------------------|-------------------------------------------------------|
| TC_001    | 2026-08-19 | Shykul Islam Siam | Asynchronous reset loads RESET_VALUE                  |
| TC_002    | 2026-08-19 | Shykul Islam Siam | Enabled data propagates through all stages            |
| TC_003    | 2026-08-19 | Shykul Islam Siam | Disabled synchronizer holds its current output        |
| TC_004    | 2026-08-19 | Shykul Islam Siam | Reset clears stale synchronized data                  |
| TC_005    | 2026-08-19 | Shykul Islam Siam | Reset asserts asynchronously while input is high      |
| TC_006    | 2026-08-19 | Shykul Islam Siam | Synchronization resumes after enable is restored      |
| TC_ALL    | 2026-08-18 | Shykul Islam Siam | All test cases                                        |

| REVISION | DATE       | AUTHOR            | DESCRIPTION                                            |
|----------|------------|-------------------|--------------------------------------------------------|
| 0.1      | 2026-08-19 | Shykul Islam Siam | Initial version                                        |
| 1.0      | 2026-08-19 | Shykul Islam Siam | Stable release                                         |

Author : Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_synchronizer_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"   // pulls in note_case(), debug, test_name, etc.

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int WIDTH = 8;                       // data bus width of the synchronizer
  localparam int STAGES = 3;                      // number of flip-flop stages in the sync chain
  localparam logic [WIDTH-1:0] RESET_VALUE = 8'hA5; // value loaded into every stage on reset
  localparam time CLK_PERIOD = 10ns;              // full clock period used to drive clk_i

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic clk_i;              // free-running testbench clock
  logic arst_ni;             // active-low asynchronous reset into the DUT
  logic en_i;                 // enable: gates whether the pipeline shifts each clock
  logic [WIDTH-1:0] data_i;  // input data driven into the synchronizer
  logic [WIDTH-1:0] data_o;  // synchronized output data read back from the DUT

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

    // instantiate the DUT with the parameters above and wire it to the tb signals
    adn_common_synchronizer #(
      .WIDTH      (WIDTH),
      .STAGES     (STAGES),
      .RESET_VALUE(RESET_VALUE)
    ) dut (
      .clk_i  (clk_i),
      .arst_ni(arst_ni),
      .en_i   (en_i),
      .data_i (data_i),
      .data_o (data_o)
    );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // compares data_o against an expected value, logs the result, and records pass/fail
  task automatic check_output(input logic [WIDTH-1:0] expected, input string description);
    bit pass;

    pass = (data_o === expected);      // use === so X/Z states are also caught as mismatches
    note_case(pass);                    // record this check for the scoreboard/summary
    if (debug || !pass) begin           // always print failures, print passes only in debug mode
      $display("[%s] %s: expected=0x%0h actual=0x%0h [%0t]",
               pass ? "PASS" : "FAIL", description, expected, data_o, $realtime);
    end
  endtask

  // applies an asynchronous reset pulse and checks the DUT loads RESET_VALUE while in reset
  task automatic reset_dut();
    arst_ni = 1'b0;                            // assert reset (active low)
    #1ns;                                       // let the async reset propagate
    check_output(RESET_VALUE, "asynchronous reset value"); // confirm output snaps to reset value
    arst_ni = 1'b1;                            // deassert reset
  endtask

  // drives data_i on a falling edge, waits a clock, then checks data_o after settling time
  task automatic drive_and_check(input logic [WIDTH-1:0] value,
                                 input logic [WIDTH-1:0] expected,
                                 input string description);
    @(negedge clk_i);      // change stimulus away from the sampling edge to avoid races
    data_i = value;
    @(posedge clk_i);      // wait for the DUT to sample/shift on the rising edge
    #1ns;                  // allow output to settle before sampling
    check_output(expected, description);
  endtask

  // TC_001: with the synchronizer disabled, reset should still force data_o to RESET_VALUE
  task automatic run_tc_001();
    en_i   = 1'b0;
    data_i = '0;
    reset_dut();
  endtask

  // TC_002: with enable high, data should shift through all STAGES pipeline stages each cycle
  task automatic run_tc_002();
    logic [WIDTH-1:0] expected [STAGES]; // shadow model of the internal pipeline stages

    en_i   = 1'b1;
    data_i = '0;
    reset_dut();
    expected = '{'0, RESET_VALUE, RESET_VALUE}; // pipeline still holds reset value right after reset

    for (int cycle = 0; cycle < 5; cycle++) begin
      // shift the shadow model one stage, mirroring what the DUT should do internally
      for (int stage = STAGES - 1; stage > 0; stage--) expected[stage] = expected[stage-1];
      expected[0] = cycle + 8'h10;              // new value entering stage 0 this cycle
      drive_and_check(cycle + 8'h10, expected[STAGES-1], // compare against the oldest/output stage
                      $sformatf("enabled pipeline cycle %0d", cycle));
    end
  endtask

  // TC_003: once the pipeline is full, disabling en_i should freeze data_o at its current value
  task automatic run_tc_003();
    en_i   = 1'b1;
    data_i = 8'h3C;
    reset_dut();
    // push the fixed value through STAGES-1 cycles; output still shows RESET_VALUE until it's full
    repeat (STAGES - 1) drive_and_check(data_i, RESET_VALUE, "pipeline fill before hold");
    drive_and_check(data_i, 8'h3C, "pipeline fill before hold"); // final stage now carries 0x3C
    check_output(8'h3C, "pipeline filled before hold");

    en_i   = 1'b0;                                              // disable: pipeline should freeze
    drive_and_check(8'hE7, 8'h3C, "disabled pipeline hold");     // new input ignored while disabled
    drive_and_check(8'h19, 8'h3C, "disabled pipeline remains held"); // still holding
  endtask

  // TC_004: reset should clear out valid/stale data already sitting in the pipeline
  task automatic run_tc_004();
    en_i   = 1'b1;
    data_i = 8'h5A;
    reset_dut();
    // fill the pipeline with a known value so we have "stale" data to clear later
    repeat (STAGES - 1) drive_and_check(data_i, RESET_VALUE, "stale data propagation");
    drive_and_check(data_i, 8'h5A, "stale data propagation");
    drive_and_check(data_i, 8'h5A, "stale data reaches output"); // confirm data made it to output

    arst_ni = 1'b0;                                              // assert reset mid-operation
    #1ns;
    check_output(RESET_VALUE, "reset clears stale synchronized data"); // stale data must be wiped
    arst_ni = 1'b1;
  endtask

  // TC_005: reset must take effect asynchronously even while input data is all 1's
  task automatic run_tc_005();
    en_i   = 1'b0;
    data_i = 8'hFF;                                             // worst-case input pattern
    reset_dut();
    check_output(RESET_VALUE, "reset holds while input is high");

    arst_ni = 1'b0;                                             // re-assert reset asynchronously
    #1ns;
    check_output(RESET_VALUE, "asynchronous reset with high input"); // must not be affected by data_i
    arst_ni = 1'b1;
  endtask

  // TC_006: after being disabled and held, re-enabling should resume normal synchronization
  task automatic run_tc_006();
    en_i   = 1'b1;
    data_i = '0;
    reset_dut();
    drive_and_check(data_i, RESET_VALUE, "initial pipeline fill");
    drive_and_check(data_i, '0, "initial pipeline fill");
    drive_and_check(data_i, '0, "initial data reaches output"); // pipeline now fully flushed to 0

    en_i = 1'b0;                                                 // disable synchronizer
    drive_and_check(8'hFF, '0, "disabled output remains stable"); // input change ignored while disabled

    en_i = 1'b1;                                                 // re-enable
    // refill the pipeline with a new value over STAGES-1 cycles; output not yet updated
    repeat (STAGES - 1) drive_and_check(8'hA6, '0, "pipeline refills after enable");
    drive_and_check(8'hA6, 8'hA6, "synchronization resumes after enable"); // new value reaches output
  endtask

  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin : main
    clk_i   = 1'b0;      // start clock low
    arst_ni = 1'b1;      // start out of reset
    en_i    = 1'b0;      // start disabled
    data_i  = '0;        // start with zero input

    fork
      forever #(CLK_PERIOD / 2) clk_i = ~clk_i;   // free-running clock generator, never joins
    join_none

    #0;                          // let initial assignments settle before dispatch
    case (test_name)              // test_name selects which test case(s) to run (from tb headers)
      "TC_001": run_tc_001();
      "TC_002": run_tc_002();
      "TC_003": run_tc_003();
      "TC_004": run_tc_004();
      "TC_005": run_tc_005();
      "TC_006": run_tc_006();
      "TC_ALL", "default": begin  
        run_tc_001();
        run_tc_002();
        run_tc_003();
        run_tc_004();
        run_tc_005();
        run_tc_006();
      end
    endcase

    $finish;                     // end simulation once selected test(s) complete

  end

endmodule                        // make simulate TOP=adn_common_synchronizer_tb TN=TC_ALL (for simulation)