/*

| TEST CASE  | DATE       | AUTHOR              | DESCRIPTION                                                                                          |
|------------|------------|---------------------|------------------------------------------------------------------------------------------------------|
| TC_DIR_01  | 2026-08-18 | Ahasan Ullah Khalid | Direct pass-through verification with rotation index set to 0 (`rotation_index_i == 0`)              |
| TC_ROT_01  | 2026-08-18 | Ahasan Ullah Khalid | Step-by-step full cyclic permutation sweep through all possible rotation indices                     |
| TC_RND_01  | 2026-08-18 | Ahasan Ullah Khalid | Randomized stimulus verification with random data patterns across all rotation indices               |
| TC_PAT_01  | 2026-08-18 | Ahasan Ullah Khalid | Walking-ones/zeros corner pattern check across input ports for cross-talk / bit mapping integrity    |
| TC_ALL     | 2026-08-18 | Ahasan Ullah Khalid | Default regression suite executing all test scenarios sequentially (`TC_DIR_01` through `TC_PAT_01`) |

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                            |
|----------|------------|---------------------|--------------------------------------------------------|
| 0.1      | 2026-08-18 | Ahasan Ullah Khalid | Initial version                                        |
| 1.0      | 2026-08-18 | Ahasan Ullah Khalid | Stable release                                         |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_rotating_xbar_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int DataWidth = 4;
  localparam int NumPorts = 4;
  localparam int IndexWidth = $clog2(NumPorts);
  localparam time CLKPeriod = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                                 clk;
  logic [IndexWidth-1:0]                rotation_index;
  logic [  NumPorts-1:0][DataWidth-1:0] in_data;
  logic [  NumPorts-1:0][DataWidth-1:0] out_data;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit                                   is_clk_edge_aligned;
  logic [  NumPorts-1:0][DataWidth-1:0] expected_data;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Clock edge alignment helper flag
  always @(posedge clk) begin
    is_clk_edge_aligned <= 1'b1;
    #1ns;
    is_clk_edge_aligned <= 1'b0;
  end

  // Golden Reference Model
  always_comb begin
    for (int i = 0; i < NumPorts; i++) begin
      expected_data[i] = in_data[(i+rotation_index)%NumPorts];
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_rotating_xbar #(
      .DATA_WIDTH(DataWidth),
      .NUM_PORTS (NumPorts)
  ) u_dut (
      .rotation_index_i(rotation_index),
      .in_i            (in_data),
      .out_o           (out_data)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic start_clock();
    fork
      forever #(CLKPeriod / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  task automatic drive_stimulus(input logic [IndexWidth-1:0] rot_idx,
                                input logic [NumPorts-1:0][DataWidth-1:0] data);
    wait (is_clk_edge_aligned);
    rotation_index <= rot_idx;
    in_data        <= data;
    @(posedge clk);
  endtask

  task automatic start_checking();
    fork
      forever
      @(posedge clk) begin
        #1ps;  // Sample post-update after combinational propagation

        // Check: Compare DUT output against Golden Reference
        if (out_data === expected_data) begin
          note_case(1);
          if (debug) begin
            $display("[%s] [PASS] Match at rot=%0d | Got: %p [%0t]", test_name, rotation_index,
                     out_data, $realtime);
          end
        end else begin
          note_case(0);
          $display("[%s] [FAIL] Mismatch at rot=%0d! Got: %p, Expected: %p [%0t]", test_name,
                   rotation_index, out_data, expected_data, $realtime);
        end
      end
    join_none
  endtask

  // Test Case: Pass-through (index = 0)
  task automatic run_tc_dir_01();
    logic [NumPorts-1:0][DataWidth-1:0] sample_payload;
    for (int i = 0; i < NumPorts; i++) begin
      sample_payload[i] = (i + 1);
    end
    drive_stimulus('0, sample_payload);
    repeat (2) @(posedge clk);
  endtask

  // Test Case: Sequential sweep through all rotation offsets
  task automatic run_tc_rot_01();
    logic [NumPorts-1:0][DataWidth-1:0] sample_payload;
    for (int i = 0; i < NumPorts; i++) begin
      sample_payload[i] = (i * 3 + 1);
    end

    for (int r = 0; r < NumPorts; r++) begin
      drive_stimulus(r[IndexWidth-1:0], sample_payload);
    end
  endtask

  // Test Case: Randomized payload and rotation sweep
  task automatic run_tc_rnd_01();
    logic [NumPorts-1:0][DataWidth-1:0] rand_payload;
    repeat (20) begin
      for (int i = 0; i < NumPorts; i++) begin
        rand_payload[i] = $urandom_range(0, (1 << DataWidth) - 1);
      end
      drive_stimulus($urandom_range(0, NumPorts - 1), rand_payload);
    end
  endtask

  // Test Case: Walking patterns (corner testing)
  task automatic run_tc_pat_01();
    logic [NumPorts-1:0][DataWidth-1:0] walking_payload;

    // Walking ones
    for (int p = 0; p < NumPorts; p++) begin
      walking_payload = '0;
      walking_payload[p] = {DataWidth{1'b1}};
      for (int r = 0; r < NumPorts; r++) begin
        drive_stimulus(r[IndexWidth-1:0], walking_payload);
      end
    end

    // Walking zeros
    for (int p = 0; p < NumPorts; p++) begin
      walking_payload = '1;
      walking_payload[p] = '0;
      for (int r = 0; r < NumPorts; r++) begin
        drive_stimulus(r[IndexWidth-1:0], walking_payload);
      end
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    // Signal initialization
    clk            = '0;
    rotation_index = '0;
    in_data        = '0;

    start_clock();
    start_checking();

    // Execute requested test scenario
    case (test_name)
      "TC_DIR_01": run_tc_dir_01();
      "TC_ROT_01": run_tc_rot_01();
      "TC_RND_01": run_tc_rnd_01();
      "TC_PAT_01": run_tc_pat_01();
      "TC_ALL": begin
        run_tc_dir_01();
        run_tc_rot_01();
        run_tc_rnd_01();
        run_tc_pat_01();
      end

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
