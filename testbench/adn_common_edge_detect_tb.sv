/*

| TEST CASE  | DATE       | AUTHOR              | DESCRIPTION                                             |
|------------|------------|---------------------|---------------------------------------------------------|
| TC_RST_01  | 2026-07-30 | Ahasan Ullah Khalid | Asynchronous Reset Assertion                            |
| TC_RST_02  | 2026-07-30 | Ahasan Ullah Khalid | Asynchronous Reset Assertion when Signal is High        |
| TC_RST_03  | 2026-07-30 | Ahasan Ullah Khalid | Reset De-assertion Recovery                             |
| TC_RISE_01 | 2026-07-30 | Ahasan Ullah Khalid | Rising edge detection trigger test (EDGE_TYPE = 0)      |
| TC_RISE_02 | 2026-07-30 | Ahasan Ullah Khalid | Sustained High input test (single-cycle pulse check)    |
| TC_FALL_01 | 2026-07-30 | Ahasan Ullah Khalid | Falling edge detection trigger test (EDGE_TYPE = 1)     |
| TC_FALL_02 | 2026-07-30 | Ahasan Ullah Khalid | Sustained Low input test (single-cycle pulse check)     |
| TC_DUAL_01 | 2026-07-30 | Ahasan Ullah Khalid | Dual edge mode trigger for Rising Edge (EDGE_TYPE = 2)  |
| TC_DUAL_02 | 2026-07-30 | Ahasan Ullah Khalid | Dual edge mode trigger for Falling Edge (EDGE_TYPE = 2) |
| TC_STR_01  | 2026-07-30 | Ahasan Ullah Khalid | Back-to-back toggle stress test at maximum frequency    |
| TC_STR_02  | 2026-07-30 | Ahasan Ullah Khalid | Sub-cycle glitch/pulse edge handling                    |
| TC_ROB_01  | 2026-07-30 | Ahasan Ullah Khalid | Unknown handling for X input and recovery to 0          |
| TC_ROB_02  | 2026-07-30 | Ahasan Ullah Khalid | Unknown handling for X input and recovery to 1          |
| TC_ROB_03  | 2026-07-30 | Ahasan Ullah Khalid | Glitch handling for Z input and recovery to 0           |
| TC_ROB_04  | 2026-07-30 | Ahasan Ullah Khalid | Glitch handling for Z input and recovery to 1           |

| REVISION   | DATE       | AUTHOR              | DESCRIPTION                                             |
|------------|------------|---------------------|---------------------------------------------------------|
| 0.1        | 2026-07-30 | Ahasan Ullah Khalid | Initial version                                         |
| 1.0        | 2026-07-30 | Ahasan Ullah Khalid | Stable release                                          |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_edge_detect_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam time CLKPeriod = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic clk;
  logic arst_n;
  logic signal_in;
  logic edge_pulse_rise;
  logic edge_pulse_fall;
  logic edge_pulse_dual;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit   is_clk_edge_aligned;

  logic ref_sig_old;
  logic ref_sig_new;
  logic is_fall;
  logic is_rise;
  logic is_dual;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Instance 0: Falling Edge Detection Mode (EDGE_TYPE = 0)
  adn_common_edge_detect #(
      .EDGE_TYPE(0)
  ) u_fall (
      .clk_i       (clk),
      .arst_ni     (arst_n),
      .signal_i    (signal_in),
      .edge_pulse_o(edge_pulse_fall)
  );

  // Instance 1: Rising Edge Detection Mode (EDGE_TYPE = 1)
  adn_common_edge_detect #(
      .EDGE_TYPE(1)
  ) u_rise (
      .clk_i       (clk),
      .arst_ni     (arst_n),
      .signal_i    (signal_in),
      .edge_pulse_o(edge_pulse_rise)
  );

  // Instance 2: Dual Edge Detection Mode (EDGE_TYPE = 2)
  adn_common_edge_detect #(
      .EDGE_TYPE(2)
  ) u_dual (
      .clk_i       (clk),
      .arst_ni     (arst_n),
      .signal_i    (signal_in),
      .edge_pulse_o(edge_pulse_dual)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  assign ref_sig_new  = signal_in;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always @(posedge clk) begin
    is_clk_edge_aligned <= arst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //Task to Apply Reset
  task automatic apply_reset();
    #100ns;
    clk         <= '0;
    arst_n      <= '0;
    signal_in   <= '0;
    ref_sig_old <= '0;
    ref_sig_new <= '0;
    is_fall     <= '0;
    is_rise     <= '0;
    is_dual     <= '0;
    #100ns;
    arst_n <= '1;
    #100ns;
  endtask

  task automatic start_clock();
    fork
      forever #(CLKPeriod / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  //Task to drive signal_in on negative clock edge
  task automatic drive_signal_in(input logic value);
    wait (is_clk_edge_aligned);
    signal_in <= value;
    @(posedge clk);
  endtask

  `define CHECK_PULSE(__REF__, __SIG__, __EDGE__)                             \
    if (``__REF__`` === ``__SIG__``) begin                                    \
      note_case(1);                                                           \
      if (debug) begin                                                        \
        $display(                                                             \
          `"``__EDGE__`` EDGE DETECTED: %b -> %b, ``__SIG__`` = %b [%0t]`",   \
            ref_sig_old, ref_sig_new, ``__SIG__``, $realtime);                \
      end                                                                     \
    end else begin                                                            \
      note_case(0);                                                           \
      $display(                                                               \
        `"``__EDGE__`` EDGE NOT DETECTED: %b -> %b, ``__SIG__`` = %b [%0t]`", \
        ref_sig_old, ref_sig_new, ``__SIG__``, $realtime);                    \
    end                                                                       \


  task automatic start_checking();
    fork
      forever
      @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
          ref_sig_old <= signal_in;
        end else begin
          ref_sig_old <= signal_in;

          if (ref_sig_old === 'z || ref_sig_old === 'x || ref_sig_new === 'z || ref_sig_new === 'x) begin
            if (debug) $display("[%s] WARNING [%0t]\nUnknown Input Signal %b Detected! Rise:%b Fall:%b Dual:%b",
              test_name, $realtime, signal_in, edge_pulse_rise, edge_pulse_fall, edge_pulse_dual);
          end else begin


            is_fall = (ref_sig_old & ~ref_sig_new);
            is_rise = (~ref_sig_old & ref_sig_new);
            is_dual = (ref_sig_old != ref_sig_new);

            `CHECK_PULSE(is_fall, edge_pulse_fall, FALLING)
            `CHECK_PULSE(is_rise, edge_pulse_rise, RISING)
            `CHECK_PULSE(is_dual, edge_pulse_dual, DUAL)
          end
        end
      end
    join_none
  endtask

  `undef CHECK_PULSE

  // Individual Test Tasks
  task automatic run_tc_rst_01();
    apply_reset();
  endtask

  task automatic run_tc_rst_02();
    apply_reset();
    drive_signal_in('1);
    arst_n <= '0;
    #(CLKPeriod / 2);
    apply_reset();
  endtask

  task automatic run_tc_rst_03();
    apply_reset();
    drive_signal_in('1);
  endtask

  task automatic run_tc_rise_01();
    apply_reset();
    drive_signal_in('1);
  endtask

  task automatic run_tc_rise_02();
    apply_reset();
    drive_signal_in('1);
    @(posedge clk);
    repeat (4) begin
      @(posedge clk);
    end
  endtask

  task automatic run_tc_fall_01();
    apply_reset();
    drive_signal_in('1);
    drive_signal_in('0);
  endtask

  task automatic run_tc_fall_02();
    apply_reset();
    drive_signal_in('1);
    drive_signal_in('0);
    repeat (4) begin
      @(posedge clk);
    end
  endtask

  task automatic run_tc_dual_01();
    apply_reset();
    drive_signal_in('1);
  endtask

  task automatic run_tc_dual_02();
    apply_reset();
    drive_signal_in('1);
    @(negedge clk);
    drive_signal_in('0);
  endtask

  task automatic run_tc_str_01();
    apply_reset();

    // Cycle 1: 0 -> 1
    drive_signal_in('1);

    // Cycle 2: 1 -> 0
    drive_signal_in('0);

    // Cycle 3: 0 -> 1
    drive_signal_in('1);

    // Cycle 4: 1 -> 0
    drive_signal_in('0);

    // Return to low steady state
    drive_signal_in('0);
  endtask

  task automatic run_tc_str_02();
    apply_reset();

    // Wait until the middle of the clock period
    #(CLKPeriod / 4);
    drive_signal_in('1);
    #(CLKPeriod / 2);
    drive_signal_in('0);
  endtask

  task automatic run_tc_rob_01();
    apply_reset();
    drive_signal_in('z);
    drive_signal_in('0);
  endtask

  task automatic run_tc_rob_02();
    apply_reset();
    drive_signal_in('z);
    drive_signal_in('1);
  endtask

  task automatic run_tc_rob_03();
    apply_reset();
    drive_signal_in('z);
    drive_signal_in('0);
  endtask

  task automatic run_tc_rob_04();
    apply_reset();
    drive_signal_in('z);
    drive_signal_in('1);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    apply_reset();

    start_clock();

    start_checking();

    case (test_name)
      "TC_RST_01":  run_tc_rst_01();
      "TC_RST_02":  run_tc_rst_02();
      "TC_RST_03":  run_tc_rst_03();
      "TC_RISE_01": run_tc_rise_01();
      "TC_RISE_02": run_tc_rise_02();
      "TC_FALL_01": run_tc_fall_01();
      "TC_FALL_02": run_tc_fall_02();
      "TC_DUAL_01": run_tc_dual_01();
      "TC_DUAL_02": run_tc_dual_02();
      "TC_STR_01":  run_tc_str_01();
      "TC_STR_02":  run_tc_str_02();
      "TC_ROB_01":  run_tc_rob_01();
      "TC_ROB_02":  run_tc_rob_02();
      "TC_ROB_03":  run_tc_rob_03();
      "TC_ROB_04":  run_tc_rob_04();

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    // Finish simulation
    $finish;
  end
endmodule
