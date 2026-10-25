/*
| TEST CASE               | DATE       | AUTHOR                     | DESCRIPTION                                                                 |
|-------------------------|------------|----------------------------|-----------------------------------------------------------------------------|
| TC_RST_01               | 2026-08-11 | Annim Jannat               | Asynchronous reset assertion with no active transfer                        |
| TC_RST_02               | 2026-08-11 | Annim Jannat               | Asynchronous reset asserted mid-transfer (both valid + ready)               |
| TC_RST_03               | 2026-08-11 | Annim Jannat               | Asynchronous reset asserted while stalled (valid high, downstream not ready)|
| TC_BASIC_PRI_01         | 2026-08-11 | Annim Jannat               | Single-beat transfer on primary only, downstream always ready               |
| TC_BASIC_SEC_01         | 2026-08-11 | Annim Jannat               | Single-beat transfer on secondary only, downstream always ready             |
| TC_BACK2BACK_PRI_01     | 2026-08-11 | Annim Jannat               | Back-to-back multi-beat transfer on primary, downstream always ready        |
| TC_PRIORITY_01          | 2026-08-11 | Annim Jannat               | Both primary and secondary valid simultaneously - primary priority check    |
| TC_SEC_STARVE_01        | 2026-08-11 | Annim Jannat               | Secondary held valid while primary is continuously valid - starvation check |
| TC_SEC_RECOVER_01       | 2026-08-11 | Annim Jannat               | Secondary starved while primary present, then primary drops - secondary xfer|
| TC_STALL_OUT_01         | 2026-08-11 | Annim Jannat               | Downstream not ready - backpressure propagates to both primary/secondary    |
| TC_VALID_TOGGLE_01      | 2026-08-11 | Annim Jannat               | Primary/secondary valid toggling independently while downstream ready       |
| TC_WIDTH_ONES_01        | 2026-08-11 | Annim Jannat               | Data integrity check with all-ones (max value) data pattern                 |
| TC_WIDTH_ZEROS_01       | 2026-08-11 | Annim Jannat               | Data integrity check with all-zeros data pattern                            |
| TC_BACK2BACK_STRESS_01  | 2026-08-11 | Annim Jannat               | Continuous dual-stream input with independently toggling downstream ready   |
| TC_RANDOM_01            | 2026-08-11 | Annim Jannat               | Stress test over many cycles                                                |
| TC_CLEAR_01             | 2026-09-31 | Md Sakhawat Hossain Sabbir |Pipeline full and downstream stalled - flush check                           |                
| TC_CLEAR_02             | 2026-09-01 | Md Sakhawat Hossain Sabbir |Pipeline empty - no effects                                                  |               
| TC_CLEAR_03             | 2026-09-01 | Md Sakhawat Hossain Sabbir |New beat is offered - capture-during-clear check                             |               
| TC_CLEAR_04             | 2026-09-01 | Md Sakhawat Hossain Sabbir |Continuous multi-beat stream on both interfaces                              |               
| TC_CLEAR_05             | 2026-09-01 | Md Sakhawat Hossain Sabbir |Followed by immediate resumption of transfers                                |               
| TC_ALL                  | 2026-09-01 | Md Sakhawat Hossain Sabbir |Executing all test scenarios sequentially                                    |               

| REVISION | DATE       | AUTHOR       | DESCRIPTION                                     |
|----------|------------|----------------------------|-----------------------------------|
| 0.1      | 2026-08-11 | Annim Jannat               | Initial version                   |
| 0.2      | 2026-08-31 | Md Sakhawat Hossain Sabbir | Stable Version                    |
| 0.3      | 2026-09-13 | Md Sakhawat Hossain Sabbir | Added coverage                    |
Authors : Annim Jannat (jannatannim@gmail.com) , Md Sakhawat Hossain Sabbir (sabbirone939@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pipeline_join_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam time CLKPeriod = 10ns;
  localparam int DATA_WIDTH = 8;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                         clk;
  logic                         arst_n;

  logic                         clear;  // Synchronous clear to flush pipeline

  // Upstream - secondary
  logic        [DATA_WIDTH-1:0] data_in_secondary;
  logic                         data_in_secondary_valid;
  logic                         data_in_secondary_ready;

  // Upstream - primary
  logic        [DATA_WIDTH-1:0] data_in_primary;
  logic                         data_in_primary_valid;
  logic                         data_in_primary_ready;

  // Downstream (joined) interface
  logic        [DATA_WIDTH-1:0] data_out;
  logic                         data_out_valid;
  logic                         data_out_ready;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit                           is_clk_edge_aligned;

  logic                         ref_is_full;
  logic        [DATA_WIDTH-1:0] ref_data_reg;

  int unsigned                  primary_xfer_count;
  int unsigned                  secondary_xfer_count;
  int unsigned                  secondary_starved_count;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // FUNCTIONAL COVERAGE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  covergroup pipeline_join_cov @(posedge clk);
    option.per_instance = 1;

    cp_reset: coverpoint arst_n {bins asserted = {0}; bins deasserted = {1};}

    cp_clear: coverpoint clear {bins inactive = {0}; bins active = {1};}

    cp_input_valid: coverpoint {
      data_in_primary_valid, data_in_secondary_valid
    } {
      bins idle = {2'b00};
      bins secondary_only = {2'b01};
      bins primary_only = {2'b10};
      bins both = {2'b11};
    }

    // 2'b01 is unreachable because primary ready follows the shared pipeline ready.
    cp_input_ready: coverpoint {
      data_in_primary_ready, data_in_secondary_ready
    } {
      bins both_not_ready = {2'b00}; bins primary_only = {2'b10}; bins both_ready = {2'b11};
    }

    cp_output_handshake: coverpoint {
      data_out_valid, data_out_ready
    } {
      bins idle = {2'b00};
      bins ready_only = {2'b01};
      bins stalled = {2'b10};
      bins transfer = {2'b11};
    }

    cp_primary_accept: coverpoint (data_in_primary_valid && data_in_primary_ready) {
      bins no_accept = {0}; bins accept = {1};
    }

    cp_secondary_accept: coverpoint (data_in_secondary_valid && data_in_secondary_ready) {
      bins no_accept = {0}; bins accept = {1};
    }

    cp_priority_block: coverpoint
        (data_in_primary_valid && data_in_secondary_valid && !data_in_secondary_ready) {
      bins no_block = {0}; bins primary_wins = {1};
    }

    cp_selected_data: coverpoint (data_in_primary_valid ? data_in_primary : data_in_secondary) {
      bins zero = {'0};
      bins all_ones = {{DATA_WIDTH{1'b1}}};
      bins a5 = {8'hA5};
      bins alternating_5a = {8'h5A};
    }
  endgroup

  pipeline_join_cov pipeline_join_cov_inst = new();


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_pipeline_join #(
      .DATA_WIDTH(DATA_WIDTH)
  ) u_dut (
      .arst_ni(arst_n),
      .clk_i  (clk),

      .clear_i(clear),

      .data_in_secondary_i      (data_in_secondary),
      .data_in_secondary_valid_i(data_in_secondary_valid),
      .data_in_secondary_ready_o(data_in_secondary_ready),

      .data_in_primary_i      (data_in_primary),
      .data_in_primary_valid_i(data_in_primary_valid),
      .data_in_primary_ready_o(data_in_primary_ready),

      .data_out_o      (data_out),
      .data_out_valid_o(data_out_valid),
      .data_out_ready_i(data_out_ready)
  );

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

  // Assert/deassert arst_n mid-test WITHOUT re-driving clk (clk is owned
  // exclusively by start_clock()'s free-running process)
  task automatic pulse_reset(input time low_time);
    arst_n <= '0;
    #(low_time);
    arst_n <= '1;
  endtask

  // Task to Apply Reset (does NOT drive clk)
  task automatic apply_reset();
    #100ns;
    arst_n                  <= '0;
    clear                   <= '0;
    data_in_primary         <= '0;
    data_in_primary_valid   <= '0;
    data_in_secondary       <= '0;
    data_in_secondary_valid <= '0;
    data_out_ready          <= '0;
    ref_is_full             <= '0;
    ref_data_reg            <= '0;
    primary_xfer_count      <= '0;
    secondary_xfer_count    <= '0;
    secondary_starved_count <= '0;
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

  // Drive both upstream interfaces together on a clean clock-aligned window.
  // Callers that only care about one stream simply pass valid=0 for the
  // other (data value is don't-care in that case).
  task automatic drive_inputs(input logic [DATA_WIDTH-1:0] pri_data, input logic pri_valid,
                              input logic [DATA_WIDTH-1:0] sec_data, input logic sec_valid);
    wait (is_clk_edge_aligned);
    data_in_primary         <= pri_data;
    data_in_primary_valid   <= pri_valid;
    data_in_secondary       <= sec_data;
    data_in_secondary_valid <= sec_valid;
    @(posedge clk);
  endtask

  // Convenience wrapper: drive primary only, secondary held idle
  task automatic drive_primary(input logic [DATA_WIDTH-1:0] data, input logic valid);
    drive_inputs(data, valid, data_in_secondary, data_in_secondary_valid & ~valid);
  endtask

  // Convenience wrapper: drive secondary only, primary held idle
  task automatic drive_secondary(input logic [DATA_WIDTH-1:0] data, input logic valid);
    drive_inputs(data_in_primary, 1'b0, data, valid);
  endtask

  // Set downstream ready independently
  task automatic set_out_ready(input logic rdy);
    wait (is_clk_edge_aligned);
    data_out_ready <= rdy;
    @(posedge clk);
  endtask

  // Set synchronous clear independently
  task automatic set_clear(input logic val);
    wait (is_clk_edge_aligned);
    clear <= val;
    @(posedge clk);
  endtask

  // Hold current data/valid/ready for N cycles (used to let stalls play out)
  task automatic hold_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  task automatic start_checking();
    // -----------------------------------------------------------------
    // LOOP A - reference model state update. Pure NBA, NO time-consuming
    // delay inside, so it can never "sleep through" an overlapping edge.
    // This mirrors the DUT's internal pipeline register exactly: it
    // reacts to posedge clk or negedge arst_n immediately, every single
    // time, with no way to miss a second edge that lands close to the
    // first.
    // -----------------------------------------------------------------
    fork
      forever
      @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
          ref_is_full  <= '0;
          ref_data_reg <= '0;
        end else begin
          automatic logic                  pl_valid;
          automatic logic [DATA_WIDTH-1:0] pl_data;
          automatic logic                  exp_pl_ready_now;

          pl_valid         = data_in_primary_valid | data_in_secondary_valid;
          pl_data          = data_in_primary_valid ? data_in_primary : data_in_secondary;
          // While full, the pipeline stage also asserts ready when clear_i
          // is asserted (it accepts/flushes during a clear), mirroring
          // adn_common_pipeline's data_in_ready_o expression.
          exp_pl_ready_now = ref_is_full ? (data_out_ready | clear) : 1'b1;

          ref_data_reg <= (pl_valid && exp_pl_ready_now) ? pl_data : ref_data_reg;
          // During clear, the RTL retains a valid input beat so capture during
          // the flush window is preserved for the following cycle.
          ref_is_full  <= clear ? pl_valid : (pl_valid ? 1'b1 : (data_out_ready ? 1'b0 : ref_is_full));
        end
      end
    join_none

    // -----------------------------------------------------------------
    // LOOP B - comparison/checking. Single edge type only (posedge clk),
    // so a short settle delay here is safe: there is no second edge type
    // it could miss while asleep. By the time this wakes and settles,
    // LOOP A has already advanced ref_is_full/ref_data_reg to reflect
    // this same edge - exactly matching the DUT's own is_full register.
    // -----------------------------------------------------------------
    fork
      forever
      @(posedge clk) begin
        #1ns;  // let DUT combinational outputs settle after the edge

        if (arst_n) begin
          begin
            automatic logic                  exp_pl_ready;
            automatic logic                  exp_primary_ready;
            automatic logic                  exp_secondary_ready;
            automatic logic                  exp_out_valid;
            automatic logic [DATA_WIDTH-1:0] exp_data;

            exp_pl_ready        = ref_is_full ? (data_out_ready | clear) : 1'b1;
            exp_primary_ready   = exp_pl_ready;
            exp_secondary_ready = exp_pl_ready & ~data_in_primary_valid;
            // data_out_valid_o is combinationally masked by clear_i
            // (is_full & ~clear_i), so the expected valid must be too.
            exp_out_valid       = ref_is_full & ~clear;
            exp_data            = ref_data_reg;

            // -----------------------------------------------------------
            // Check 1: data_in_primary_ready_o
            // -----------------------------------------------------------
            if (data_in_primary_ready !== exp_primary_ready) begin
              note_case(0);
              $display(
                  "[%s] FAIL [%0t] data_in_primary_ready_o mismatch: exp=%b got=%b (is_full=%b out_rdy=%b clear=%b)",
                  test_name, $realtime, exp_primary_ready, data_in_primary_ready, ref_is_full,
                  data_out_ready, clear);
            end else begin
              note_case(1);
            end

            // -----------------------------------------------------------
            // Check 2: data_in_secondary_ready_o (priority-gated signal)
            // -----------------------------------------------------------
            if (data_in_secondary_ready !== exp_secondary_ready) begin
              note_case(0);
              $display(
                  "[%s] FAIL [%0t] data_in_secondary_ready_o mismatch: exp=%b got=%b (pri_vld=%b)",
                  test_name, $realtime, exp_secondary_ready, data_in_secondary_ready,
                  data_in_primary_valid);
            end else begin
              note_case(1);
            end

            // -----------------------------------------------------------
            // Check 3: data_out_valid_o
            // -----------------------------------------------------------
            if (data_out_valid !== exp_out_valid) begin
              note_case(0);
              $display(
                  "[%s] FAIL [%0t] data_out_valid_o mismatch: exp=%b got=%b (is_full=%b clear=%b)",
                  test_name, $realtime, exp_out_valid, data_out_valid, ref_is_full, clear);
            end else begin
              note_case(1);
            end

            // -----------------------------------------------------------
            // Check 4: data_out_o integrity while valid
            // -----------------------------------------------------------
            if (exp_out_valid && (data_out !== exp_data)) begin
              note_case(0);
              $display("[%s] FAIL [%0t] data_out_o mismatch: exp=%0h got=%0h", test_name,
                       $realtime, exp_data, data_out);
            end else if (exp_out_valid) begin
              note_case(1);
            end

            // -----------------------------------------------------------
            // Transfer counters (actual completed handshakes at the DUT
            // input boundary)
            // -----------------------------------------------------------
            if (data_in_primary_valid && data_in_primary_ready) begin
              primary_xfer_count <= primary_xfer_count + 1;
            end
            if (data_in_secondary_valid && data_in_secondary_ready) begin
              secondary_xfer_count <= secondary_xfer_count + 1;
            end

            // -----------------------------------------------------------
            // Informational: secondary offering valid data but denied
            // acceptance purely because primary is asserting valid this
            // same cycle (documented priority-mux behavior, not a bug).
            // -----------------------------------------------------------
            if (data_in_secondary_valid && data_in_primary_valid && !data_in_secondary_ready) begin
              secondary_starved_count <= secondary_starved_count + 1;
              if (debug) begin
                $display("[%s] INFO [%0t] secondary starved by primary priority (count=%0d)",
                         test_name, $realtime, secondary_starved_count + 1);
              end
            end

            if (debug) begin
              $display(
                  "[%s] STATE [%0t] is_full=%b data_reg=%0h pri_rdy=%b sec_rdy=%b out_vld=%b clear=%b",
                  test_name, $realtime, ref_is_full, ref_data_reg, data_in_primary_ready,
                  data_in_secondary_ready, data_out_valid, clear);
            end
          end
        end
      end
    join_none
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic run_tc_rst_01();
    apply_reset();
  endtask

  task automatic run_tc_rst_02();
    apply_reset();
    set_out_ready(1);
    drive_inputs(8'hA5, 1, 8'h5A, 1);
    pulse_reset(CLKPeriod);
    hold_cycles(3);
  endtask

  task automatic run_tc_rst_03();
    // Reset asserted mid-stall (valid high, downstream not ready)
    apply_reset();
    set_out_ready(0);
    drive_inputs(8'h3C, 1, 8'h00, 0);
    hold_cycles(3);
    pulse_reset(CLKPeriod);
    hold_cycles(3);
  endtask

  task automatic run_tc_basic_pri_01();
    // Single beat on primary only, downstream ready
    apply_reset();
    set_out_ready(1);
    drive_primary(8'h11, 1);
    drive_primary(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_basic_sec_01();
    // Single beat on secondary only, downstream ready
    apply_reset();
    set_out_ready(1);
    drive_secondary(8'h22, 1);
    drive_secondary(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_back2back_pri_01();
    // Back-to-back beats on primary, downstream always ready
    apply_reset();
    set_out_ready(1);
    drive_primary(8'h01, 1);
    drive_primary(8'h02, 1);
    drive_primary(8'h03, 1);
    drive_primary(8'h04, 1);
    drive_primary(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_priority_01();
    // Both primary and secondary valid simultaneously - primary must win
    apply_reset();
    set_out_ready(1);
    drive_inputs(8'hAA, 1, 8'hBB, 1);
    drive_inputs(8'h00, 0, 8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_sec_starve_01();
    // Secondary held valid while primary is continuously valid: secondary
    // must never be accepted for the duration
    apply_reset();
    set_out_ready(1);
    for (int i = 0; i < 6; i++) begin
      drive_inputs(i[DATA_WIDTH-1:0], 1, 8'hFE, 1);
    end
    drive_inputs(8'h00, 0, 8'hFE, 1);
    hold_cycles(3);
  endtask

  task automatic run_tc_sec_recover_01();
    // Secondary starved while primary present, then primary drops and
    // secondary should be accepted
    apply_reset();
    set_out_ready(1);
    drive_inputs(8'h10, 1, 8'h20, 1);
    hold_cycles(2);
    drive_inputs(8'h00, 0, 8'h20, 1);
    hold_cycles(3);
    drive_inputs(8'h00, 0, 8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_stall_out_01();
    // Downstream not ready: backpressure should propagate to both streams
    apply_reset();
    set_out_ready(0);
    drive_primary(8'h5A, 1);
    hold_cycles(3);
    drive_secondary(8'hA5, 1);
    hold_cycles(3);
    set_out_ready(1);
    hold_cycles(3);
  endtask

  task automatic run_tc_valid_toggle_01();
    // Primary/secondary valid toggling independently while downstream ready
    apply_reset();
    set_out_ready(1);
    drive_inputs(8'h01, 1, 8'h00, 0);
    drive_inputs(8'h00, 0, 8'h02, 1);
    drive_inputs(8'h03, 1, 8'h04, 1);
    drive_inputs(8'h00, 0, 8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_width_ones_01();
    apply_reset();
    set_out_ready(1);
    drive_primary({DATA_WIDTH{1'b1}}, 1);
    drive_primary(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_width_zeros_01();
    apply_reset();
    set_out_ready(1);
    drive_secondary({DATA_WIDTH{1'b0}}, 1);
    drive_secondary(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_back2back_stress_01();
    // Continuous dual-stream input with independently toggling downstream ready
    apply_reset();
    for (int i = 0; i < 20; i++) begin
      set_out_ready($urandom_range(0, 1));
      drive_inputs(i[DATA_WIDTH-1:0], $urandom_range(0, 1), ~i[DATA_WIDTH-1:0], $urandom_range(0, 1
                   ));
    end
    drive_inputs(8'h00, 0, 8'h00, 0);
    set_out_ready(1);
    hold_cycles(5);
  endtask

  task automatic run_tc_random_01();
    // Fully randomized valid/ready/data over many cycles
    apply_reset();
    for (int i = 0; i < 50; i++) begin
      set_out_ready($urandom_range(0, 1));
      drive_inputs($urandom, $urandom_range(0, 1), $urandom, $urandom_range(0, 1));
    end
    drive_inputs(8'h00, 0, 8'h00, 0);
    set_out_ready(1);
    hold_cycles(5);
  endtask

  task automatic run_tc_clear_01();
    // Clear asserted while pipeline is full and downstream is stalled:
    // data_out_valid_o should drop combinationally the same cycle, and
    // is_full should be clear the cycle after.
    apply_reset();
    set_out_ready(0);
    drive_primary(8'h77, 1);
    drive_primary(8'h00, 0);
    hold_cycles(2);
    set_clear(1);
    hold_cycles(1);
    set_clear(0);
    hold_cycles(3);
  endtask

  task automatic run_tc_clear_02();
    // Clear asserted while the pipeline is empty: should be a no-op,
    // ready must remain asserted throughout.
    apply_reset();
    set_out_ready(1);
    set_clear(1);
    hold_cycles(2);
    set_clear(0);
    hold_cycles(2);
  endtask

  task automatic run_tc_clear_03();
    // Clear asserted while pipeline full/stalled, then a new beat is
    // offered during the clear window: ready is still forced high while
    // full & clear, so the new data may be captured even mid-flush.
    apply_reset();
    set_out_ready(0);
    drive_primary(8'h11, 1);
    drive_primary(8'h00, 0);
    hold_cycles(2);
    set_clear(1);
    drive_primary(8'h99, 1);
    hold_cycles(1);
    drive_primary(8'h00, 0);
    set_clear(0);
    hold_cycles(3);
  endtask

  task automatic run_tc_clear_04();
    // Clear held across several cycles of continuous dual-stream input:
    // output must stay flushed the entire time despite ongoing traffic.
    apply_reset();
    set_out_ready(1);
    set_clear(1);
    for (int i = 0; i < 5; i++) begin
      drive_inputs(i[DATA_WIDTH-1:0], 1, ~i[DATA_WIDTH-1:0], 1);
    end
    set_clear(0);
    drive_inputs(8'h00, 0, 8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_clear_05();
    // Single-cycle clear pulse followed immediately by a normal transfer,
    // to check the pipeline resumes cleanly right after a flush.
    apply_reset();
    set_out_ready(1);
    drive_primary(8'h44, 1);
    drive_primary(8'h00, 0);
    hold_cycles(1);
    set_clear(1);
    hold_cycles(1);
    set_clear(0);
    drive_primary(8'h55, 1);
    drive_primary(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_all();
    run_tc_rst_01();
    run_tc_rst_02();
    run_tc_rst_03();
    run_tc_basic_pri_01();
    run_tc_basic_sec_01();
    run_tc_back2back_pri_01();
    run_tc_priority_01();
    run_tc_sec_starve_01();
    run_tc_sec_recover_01();
    run_tc_stall_out_01();
    run_tc_valid_toggle_01();
    run_tc_width_ones_01();
    run_tc_width_zeros_01();
    run_tc_back2back_stress_01();
    run_tc_random_01();
    run_tc_clear_01();
    run_tc_clear_02();
    run_tc_clear_03();
    run_tc_clear_04();
    run_tc_clear_05();
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin

    clk = '0;

    apply_reset();

    start_clock();

    start_checking();

    case (test_name)
      "TC_RST_01":              run_tc_rst_01();
      "TC_RST_02":              run_tc_rst_02();
      "TC_RST_03":              run_tc_rst_03();
      "TC_BASIC_PRI_01":        run_tc_basic_pri_01();
      "TC_BASIC_SEC_01":        run_tc_basic_sec_01();
      "TC_BACK2BACK_PRI_01":    run_tc_back2back_pri_01();
      "TC_PRIORITY_01":         run_tc_priority_01();
      "TC_SEC_STARVE_01":       run_tc_sec_starve_01();
      "TC_SEC_RECOVER_01":      run_tc_sec_recover_01();
      "TC_STALL_OUT_01":        run_tc_stall_out_01();
      "TC_VALID_TOGGLE_01":     run_tc_valid_toggle_01();
      "TC_WIDTH_ONES_01":       run_tc_width_ones_01();
      "TC_WIDTH_ZEROS_01":      run_tc_width_zeros_01();
      "TC_BACK2BACK_STRESS_01": run_tc_back2back_stress_01();
      "TC_RANDOM_01":           run_tc_random_01();
      "TC_CLEAR_01":            run_tc_clear_01();
      "TC_CLEAR_02":            run_tc_clear_02();
      "TC_CLEAR_03":            run_tc_clear_03();
      "TC_CLEAR_04":            run_tc_clear_04();
      "TC_CLEAR_05":            run_tc_clear_05();
      "TC_ALL":                 run_tc_all();

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    $display("[%s] SUMMARY: primary_xfers=%0d secondary_xfers=%0d secondary_starved_events=%0d",
             test_name, primary_xfer_count, secondary_xfer_count, secondary_starved_count);

    if (pipeline_join_cov_inst.get_inst_coverage() < 100.0) begin

      $display("WARNING: Functional coverage is below 100%%");

    end else begin

      $display("FUNCTIONAL COVERAGE: 100%%");

    end

    #100ns;

    $finish;

  end


endmodule
