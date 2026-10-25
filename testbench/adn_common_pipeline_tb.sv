/*

| TEST CASE | TEST NAME                  | DATE       | AUTHOR                       | DESCRIPTION                                                                 |
|-----------|----------------------------|------------|------------------------------|-----------------------------------------------------------------------------|
| TC_001    | `simple_transfer`          | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies a single valid data transfer through the pipeline.                 |
| TC_002    | `back_to_back`             | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies consecutive back-to-back input and output transfers.               |
| TC_003    | `output_backpressure`      | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies that output data remains stable while downstream is stalled.       |
| TC_004    | `random_traffic`           | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies random data transfers with random valid and ready behavior.        |
| TC_005    | `clear_flush`              | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies that clear flushes valid data currently stored in the pipeline.    |
| TC_006    | `clear_backpressure`       | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies clear operation while downstream backpressure is asserted.         |
| TC_007    | `clear_blocks_input`       | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies that clear prevents input transfers and output validity.           |
| TC_008    | `operation_after_clear`    | 2026-09-01 | Md. Sakib Hasan Shawon       | Verifies normal pipeline operation after clear is released.                 |
| --------- | `all`                      | 2026-09-01 | Md. Sakib Hasan Shawon       | Runs the complete directed pipeline test suite.                             |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-01 | Md. Sakib Hasan Shawon | Initial version                                 |
| 1.0      | 2026-09-01 | Md. Sakib Hasan Shawon | Stable release                                  |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pipeline_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pipeline data width.
  parameter int DATA_WIDTH = 32;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Clock and reset.
  logic                  clk_i;
  logic                  arst_ni;

  // Pipeline clear.
  logic                  clear_i;

  // Input interface.
  logic [DATA_WIDTH-1:0] data_in_i;
  logic                  data_in_valid_i;
  logic                  data_in_ready_o;

  // Output interface.
  logic [DATA_WIDTH-1:0] data_out_o;
  logic                  data_out_valid_o;
  logic                  data_out_ready_i;

  // Reference queue used by the random traffic test.
  logic [DATA_WIDTH-1:0] expected_q       [$];

  // Random stimulus.
  logic [DATA_WIDTH-1:0] rand_data;
  logic                  rand_valid;
  logic                  rand_ready;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK GENERATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial clk_i = 1'b0;

  always #5 clk_i <= ~clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RESET GENERATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    arst_ni = 1'b0;

    repeat (5) @(posedge clk_i);

    arst_ni = 1'b1;

  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_pipeline #(
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .clear_i         (clear_i),
      .data_in_i       (data_in_i),
      .data_in_valid_i (data_in_valid_i),
      .data_in_ready_o (data_in_ready_o),
      .data_out_o      (data_out_o),
      .data_out_valid_o(data_out_valid_o),
      .data_out_ready_i(data_out_ready_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Wait until an input transaction is accepted by the DUT.
  task automatic wait_input_handshake();
    do @(posedge clk_i); while (!(data_in_valid_i && data_in_ready_o));
    #1;
  endtask

  // Wait until an output transaction is accepted by the downstream.
  task automatic wait_output_handshake();
    do @(posedge clk_i); while (!(data_out_valid_o && data_out_ready_i));
  endtask

  // Check output data against the expected value.
  task automatic check_data(input logic [DATA_WIDTH-1:0] expected_data, input string case_name);

    logic result;

    result = (data_out_valid_o && (data_out_o === expected_data));

    if (result) begin
      $display("PASS: %-30s data=0x%08h", case_name, data_out_o);
    end else begin
      $display("FAIL: %-30s data=0x%08h (expected=0x%08h valid=%b)", case_name, data_out_o,
               expected_data, data_out_valid_o);
    end

    note_case(result);

  endtask

  // Check pipeline valid and ready state.
  task automatic check_state(input logic expected_valid, input logic expected_ready,
                             input string case_name);

    logic result;

    result = ((data_out_valid_o === expected_valid) && (data_in_ready_o === expected_ready));

    if (result) begin
      $display("PASS: %-30s in_ready=%b out_valid=%b", case_name, data_in_ready_o,
               data_out_valid_o);
    end else begin
      $display("FAIL: %-30s in_ready=%b (exp=%b) out_valid=%b (exp=%b)", case_name,
               data_in_ready_o, expected_ready, data_out_valid_o, expected_valid);
    end

    note_case(result);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 1
  // SIMPLE DATA TRANSFER
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_1_simple_transfer();

    $display("\n========== TEST 1: SIMPLE DATA TRANSFER ==========");

    // Configure normal pipeline operation.
    clear_i          <= 1'b0;
    data_out_ready_i <= 1'b1;

    // Present one input transaction.
    data_in_i        <= 32'hDEADBEEF;
    data_in_valid_i  <= 1'b1;

    // Wait for input transfer.
    wait_input_handshake();

    // Remove input valid after the transfer.
    data_in_valid_i <= 1'b0;

    // Wait for output transfer.
    wait_output_handshake();

    // Verify transferred data.
    check_data(32'hDEADBEEF, "TEST 1: SIMPLE TRANSFER");

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 2
  // BACK-TO-BACK TRANSFERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_2_back_to_back();

    logic result;

    $display("\n========== TEST 2: BACK-TO-BACK TRANSFERS ==========");

    clear_i          <= 1'b0;
    data_out_ready_i <= 1'b1;
    data_in_valid_i  <= 1'b1;

    result = 1'b1;

    // Send consecutive transactions.
    for (int i = 0; i < 5; i++) begin

      data_in_i <= i;

      // Wait until the current input word is accepted.
      wait_input_handshake();

      // Wait for the corresponding output.
      wait_output_handshake();

      if (data_out_o !== i) begin

        result = 1'b0;

        $display("FAIL: TEST 2.%0d: expected=0x%08h got=0x%08h", i + 1, i, data_out_o);

      end

    end

    data_in_valid_i <= 1'b0;

    if (result) begin
      $display("PASS: %-30s transfers=5", "TEST 2: BACK-TO-BACK");
    end

    note_case(result);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 3
  // OUTPUT BACKPRESSURE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_3_output_backpressure();

    logic [DATA_WIDTH-1:0] held_data;
    logic                  result;

    $display("\n========== TEST 3: OUTPUT BACKPRESSURE ==========");

    // Start with downstream ready so the input can be accepted.
    clear_i          <= 1'b0;
    data_out_ready_i <= 1'b1;

    data_in_i        <= 32'hCAFEBABE;
    data_in_valid_i  <= 1'b1;

    // Accept input.
    wait_input_handshake();

    data_in_valid_i <= 1'b0;

    // Wait for output valid to appear.
    while (!data_out_valid_o) begin
      @(posedge clk_i);
    end

    #1;

    // Immediately apply backpressure.
    data_out_ready_i <= 1'b0;

    held_data = data_out_o;

    // Verify correct data is held.
    result = (data_out_valid_o && (data_out_o === 32'hCAFEBABE));

    if (result) begin
      $display("PASS: %-30s data=0x%08h", "TEST 3: OUTPUT BACKPRESSURE", data_out_o);
    end else begin
      $display("FAIL: %-30s data=0x%08h expected=0x%08h valid=%b", "TEST 3: OUTPUT BACKPRESSURE",
               data_out_o, 32'hCAFEBABE, data_out_valid_o);
    end

    note_case(result);

    // Verify output remains stable while stalled.
    result = 1'b1;

    repeat (3) begin
      @(posedge clk_i);
      #1;

      if (!(data_out_valid_o && (data_out_o === held_data))) begin
        result = 1'b0;
        $display("FAIL: %-30s output changed during stall", "TEST 3: DATA STABILITY");
      end
    end

    if (result) begin
      $display("PASS: %-30s output stable during stall", "TEST 3: DATA STABILITY");
    end

    note_case(result);

    // Release downstream.
    data_out_ready_i <= 1'b1;

    // Wait for output transfer.
    wait_output_handshake();

    @(posedge clk_i);
    #1;

    check_state(1'b0, 1'b1, "TEST 3: PIPELINE EMPTY");

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 4
  // RANDOM TRAFFIC
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_4_random_traffic();

    logic [DATA_WIDTH-1:0] exp_data;
    logic                  result;

    $display("\n========== TEST 4: RANDOM TRAFFIC ==========");

    expected_q.delete();

    // Initialize interface.
    clear_i          <= 1'b0;
    data_in_i        <= '0;
    data_in_valid_i  <= 1'b0;
    data_out_ready_i <= 1'b0;

    repeat (2) @(posedge clk_i);

    result = 1'b1;

    // Generate random traffic.
    for (int i = 0; i < 20; i++) begin

      rand_data  = $urandom;
      rand_valid = $urandom_range(0, 1);
      rand_ready = $urandom_range(0, 1);

      data_in_i        <= rand_data;
      data_in_valid_i  <= rand_valid;
      data_out_ready_i <= rand_ready;

      @(posedge clk_i);

      // Record accepted input.
      if (rand_valid && data_in_ready_o) expected_q.push_back(rand_data);

      // Check accepted output.
      if (data_out_valid_o && rand_ready) begin

        if (expected_q.size() == 0) begin

          result = 1'b0;

          $display("FAIL: TEST 4: Unexpected output=0x%08h", data_out_o);

        end else begin

          exp_data = expected_q.pop_front();

          if (data_out_o !== exp_data) begin

            result = 1'b0;

            $display("FAIL: TEST 4: expected=0x%08h got=0x%08h", exp_data, data_out_o);

          end

        end

      end

    end

    // Stop new input traffic and drain the pipeline.
    data_in_valid_i  <= 1'b0;
    data_out_ready_i <= 1'b1;

    while (expected_q.size() > 0) begin

      @(posedge clk_i);

      if (data_out_valid_o) begin

        exp_data = expected_q.pop_front();

        if (data_out_o !== exp_data) begin

          result = 1'b0;

          $display("FAIL: TEST 4: DRAIN expected=0x%08h got=0x%08h", exp_data, data_out_o);

        end

      end

    end

    // Verify pipeline is empty.
    @(posedge clk_i);

    if (data_out_valid_o) begin

      result = 1'b0;

      $display("FAIL: TEST 4: Pipeline not empty after drain");

    end

    if (result) begin
      $display("PASS: %-30s random traffic verified", "TEST 4: RANDOM TRAFFIC");
    end

    note_case(result);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 5
  // CLEAR FLUSH
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_5_clear_flush();

    $display("\n========== TEST 5: CLEAR FLUSH ==========");

    // Stall downstream so data remains in the pipeline.
    clear_i          <= 1'b0;
    data_out_ready_i <= 1'b0;
    data_in_valid_i  <= 1'b0;

    @(posedge clk_i);

    // Insert data into the pipeline.
    data_in_i       <= 32'h12345678;
    data_in_valid_i <= 1'b1;

    wait_input_handshake();

    data_in_valid_i <= 1'b0;

    // Verify that data is stored.
    @(posedge clk_i);
    #1;
    check_data(32'h12345678, "TEST 5: DATA STORED");

    // Assert synchronous clear.
    clear_i <= 1'b1;

    @(posedge clk_i);
    #1;

    // Clear must flush data.
    // The RTL keeps input ready asserted during clear.
    check_state(1'b0, 1'b1, "TEST 5: CLEAR ACTIVE");

    // Release clear.
    clear_i <= 1'b0;

    @(posedge clk_i);

    // Flushed data must not return.
    check_state(1'b0, 1'b1, "TEST 5: POST-CLEAR");

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 6
  // CLEAR DURING OUTPUT BACKPRESSURE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_6_clear_backpressure();

    $display("\n========== TEST 6: CLEAR DURING BACKPRESSURE ==========");

    // Stall downstream.
    clear_i          <= 1'b0;
    data_out_ready_i <= 1'b0;
    data_in_valid_i  <= 1'b0;

    @(posedge clk_i);

    // Insert data.
    data_in_i       <= 32'hCAFEBABE;
    data_in_valid_i <= 1'b1;

    wait_input_handshake();

    data_in_valid_i <= 1'b0;

    // Verify that stalled data is preserved.
    repeat (2) @(posedge clk_i);

    check_data(32'hCAFEBABE, "TEST 6: DATA DURING BACKPRESSURE");

    // Assert clear while downstream remains stalled.
    clear_i <= 1'b1;

    @(posedge clk_i);
    #1;

    // Clear must flush the stalled data.
    // The RTL keeps input ready asserted during clear.
    check_state(1'b0, 1'b1, "TEST 6: CLEAR FLUSH");

    // Release clear and downstream.
    clear_i          <= 1'b0;
    data_out_ready_i <= 1'b1;

    @(posedge clk_i);

    // Flushed data must not reappear.
    check_state(1'b0, 1'b1, "TEST 6: POST-CLEAR");

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 7
  // CLEAR BLOCKS INPUT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_7_clear_blocks_input();

    $display("\n========== TEST 7: CLEAR BLOCKS INPUT ==========");

    // Assert clear while presenting valid input.
    clear_i          <= 1'b1;
    data_out_ready_i <= 1'b1;
    data_in_i        <= 32'hFACEFACE;
    data_in_valid_i  <= 1'b1;

    @(posedge clk_i);
    #1;

    // During clear, output must be invalid.
    // The RTL keeps input ready asserted during clear.
    check_state(1'b0, 1'b1, "TEST 7: CLEAR ACTIVE");

    // Remove the input transaction while clear is STILL active.
    // This prevents it from being accepted after clear is released.
    data_in_valid_i <= 1'b0;

    // Release clear.
    clear_i <= 1'b0;

    @(posedge clk_i);
    #1;

    // Data presented during clear must not appear at the output.
    check_state(1'b0, 1'b1, "TEST 7: POST-CLEAR");

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 8
  // NORMAL OPERATION AFTER CLEAR
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_8_operation_after_clear();

    $display("\n========== TEST 8: NORMAL OPERATION AFTER CLEAR ==========");

    // Configure normal operation.
    clear_i          <= 1'b0;
    data_out_ready_i <= 1'b1;
    data_in_valid_i  <= 1'b0;

    @(posedge clk_i);

    // Send a new transaction.
    data_in_i       <= 32'hA5A5A5A5;
    data_in_valid_i <= 1'b1;

    wait_input_handshake();

    data_in_valid_i <= 1'b0;

    // Wait for output transfer.
    wait_output_handshake();

    // Verify data after clear.
    check_data(32'hA5A5A5A5, "TEST 8: NORMAL OPERATION");

  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAIN TEST
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    // Initialize DUT inputs.
    clear_i          = 1'b0;
    data_in_i        = '0;
    data_in_valid_i  = 1'b0;
    data_out_ready_i = 1'b1;

    // Wait for reset release.
    @(posedge arst_ni);
    @(posedge clk_i);

    $display("\n");
    $display("============================================================");
    $display("              ADN COMMON PIPELINE TESTBENCH");
    $display("============================================================");
    $display("DATA_WIDTH = %0d", DATA_WIDTH);

    // Only the selected test is executed unless TC_ALL is specified.
    case (test_name)

      "TC_001", "simple_transfer": test_1_simple_transfer();

      "TC_002", "back_to_back": test_2_back_to_back();

      "TC_003", "output_backpressure": test_3_output_backpressure();

      "TC_004", "random_traffic": test_4_random_traffic();

      "TC_005", "clear_flush": test_5_clear_flush();

      "TC_006", "clear_backpressure": test_6_clear_backpressure();

      "TC_007", "clear_blocks_input": test_7_clear_blocks_input();

      "TC_008", "operation_after_clear": test_8_operation_after_clear();

      "TC_ALL", "all", "default": begin

        test_1_simple_transfer();
        test_2_back_to_back();
        test_3_output_backpressure();
        test_4_random_traffic();
        test_5_clear_flush();
        test_6_clear_backpressure();
        test_7_clear_blocks_input();
        test_8_operation_after_clear();

      end

    endcase

    $display("\n");
    $display("============================================================");
    $display("                 PIPELINE TEST COMPLETE");
    $display("============================================================");

    $finish;

  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TIMEOUT WATCHDOG
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    #10000000;

    $error("Testbench timeout");
    $finish;

  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WAVEFORM DUMP
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    $dumpfile("adn_common_pipeline_tb.vcd");
    $dumpvars(0, adn_common_pipeline_tb);

  end

endmodule
