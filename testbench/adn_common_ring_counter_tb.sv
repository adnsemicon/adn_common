/*

| TEST CASE  | DATE       | AUTHOR              | DESCRIPTION                                                                                           |
|------------|------------|---------------------|-------------------------------------------------------------------------------------------------------|
| TC_RST_01  | 2026-08-09 | Ahasan Ullah Khalid | Active-low reset assertion and default state initialization check (`data_o == 'd1`)                   |
| TC_RST_02  | 2026-08-09 | Ahasan Ullah Khalid | Reset re-assertion mid-operation while rotation is actively running                                   |
| TC_ROT_01  | 2026-08-09 | Ahasan Ullah Khalid | Continuous full circular shift and wrap-around test with sustained enable (`enable == 1`)             |
| TC_ENA_01  | 2026-08-09 | Ahasan Ullah Khalid | Enable de-assertion hold test (verifies rotation pauses and output holds state when `enable == 0`)    |
| TC_ENA_02  | 2026-08-09 | Ahasan Ullah Khalid | Single-pulse enable step test (verifies 1-bit advance per single cycle enable pulse)                  |
| TC_ALL     | 2026-08-09 | Ahasan Ullah Khalid | Default regression suite executing all test scenarios sequentially (`TC_RST_01` through `TC_ENA_02`)  |

| REVISION   | DATE       | AUTHOR              | DESCRIPTION                                                                                           |
|------------|------------|---------------------|-------------------------------------------------------------------------------------------------------|
| 0.1        | 2026-07-30 | Ahasan Ullah Khalid | Initial version                                                                                       |
| 1.0        | 2026-08-09 | Ahasan Ullah Khalid | Stable release                                                                                        |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_ring_counter_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int DataWidth = 4;
  localparam time CLKPeriod = 10ns;
  localparam logic [DataWidth-1:0] ResetValue = {1'b1, {(DataWidth - 1) {1'b0}}};

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                 clk;
  logic                 arst_n;
  logic                 enable;
  logic [DataWidth-1:0] data;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit                   is_clk_edge_aligned;
  logic [DataWidth-1:0] expected_data;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_ring_counter #(
      .DATA_WIDTH(DataWidth)
  ) u_dut (
      .clk_i   (clk),
      .arst_ni (arst_n),
      .enable_i(enable),
      .data_o  (data)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Clock edge alignment helper flag (Standard procedural always block for delay)
  always @(posedge clk) begin
    is_clk_edge_aligned <= arst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  // Golden Reference Model matching DUT's Asynchronous Reset & Circular Shift Logic
  always @(posedge clk or negedge arst_n) begin
    if (~arst_n) begin
      expected_data <= ResetValue;
    end else if (enable) begin
      expected_data <= {expected_data[DataWidth-2:0], expected_data[DataWidth-1]};
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic start_clock();
    fork
      forever #(CLKPeriod / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  task automatic apply_reset();
    arst_n <= '0;
    enable <= '0;
    repeat (2) @(posedge clk);
    arst_n <= '1;
    @(posedge clk);
  endtask

  task automatic drive_enable(input logic value);
    wait (is_clk_edge_aligned);
    enable <= value;
    @(posedge clk);
  endtask

  task automatic start_checking();
    fork
      forever
      @(posedge clk) begin
        #1ps;  // Sample post-clock edge update

        // Check 1: One-hot Assertion
        if ($onehot(data)) begin
          note_case(1);
        end else begin
          note_case(0);
          $display("[%s] [FAIL] One-hot property violated! data = %b [%0t]", test_name, data,
                   $realtime);
        end

        // Check 2: Match against Golden Reference
        if (data === expected_data) begin
          note_case(1);
          if (debug) $display("[%s] [PASS] Match: %b [%0t]", test_name, data, $realtime);
        end else begin
          note_case(0);
          $display("[%s] [FAIL] Value Mismatch! Got: %b, Expected: %b [%0t]", test_name, data,
                   expected_data, $realtime);
        end
      end
    join_none
  endtask

  // Test Case Tasks
  task automatic run_tc_rst_01();
    apply_reset();
  endtask

  task automatic run_tc_rst_02();
    apply_reset();
    drive_enable('1);
    repeat (2) @(posedge clk);
    arst_n <= '0;
    repeat (2) @(posedge clk);
    arst_n <= '1;
    @(posedge clk);
  endtask

  task automatic run_tc_rot_01();
    apply_reset();
    drive_enable('1);
    repeat (DataWidth * 2) @(posedge clk);
    drive_enable('0);
  endtask

  task automatic run_tc_ena_01();
    apply_reset();
    drive_enable('1);
    repeat (2) @(posedge clk);
    drive_enable('0);
    repeat (3) @(posedge clk);
    drive_enable('1);
    repeat (2) @(posedge clk);
    drive_enable('0);
  endtask

  task automatic run_tc_ena_02();
    apply_reset();
    repeat (DataWidth) begin
      drive_enable('1);
      drive_enable('0);
      repeat (2) @(posedge clk);
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    // Signal initialization
    clk    = '0;
    arst_n = '0;
    enable = '0;

    start_clock();
    start_checking();

    // Execute requested test scenario
    case (test_name)
      "TC_RST_01": run_tc_rst_01();
      "TC_RST_02": run_tc_rst_02();
      "TC_ROT_01": run_tc_rot_01();
      "TC_ENA_01": run_tc_ena_01();
      "TC_ENA_02": run_tc_ena_02();
      "TC_ALL": begin
        run_tc_rst_01();
        run_tc_rst_02();
        run_tc_rot_01();
        run_tc_ena_01();
        run_tc_ena_02();
      end

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
