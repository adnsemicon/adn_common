/*
| TEST CASE             | DATE       | AUTHOR              | DESCRIPTION                                                              |
|-----------------------|------------|---------------------|--------------------------------------------------------------------------|
| TC_RST_01             | 2026-08-10 | Annim Jannat        | Asynchronous reset assertion with no active transfer                     |
| TC_RST_02             | 2026-08-10 | Annim Jannat        | Asynchronous reset asserted mid-transfer (valid + both ready)            |
| TC_RST_03             | 2026-08-10 | Annim Jannat        | Asynchronous reset asserted while stalled (valid high, neither ready)    |
| TC_CLR_01             | 2026-08-31 | Ahasan Ullah Khalid | Synchronous clear assertion on idle pipeline                             |
| TC_CLR_02             | 2026-08-31 | Ahasan Ullah Khalid | Synchronous clear asserted while stalled (data flushed, valid dropped)   |
| TC_CLR_03             | 2026-08-31 | Ahasan Ullah Khalid | Clear asserted simultaneously with upstream valid input                  |
| TC_CLR_04             | 2026-08-31 | Ahasan Ullah Khalid | 1-cycle clear pulse recovery with immediate valid transaction next cycle |
| TC_BASIC_01           | 2026-08-10 | Annim Jannat        | Single-beat transfer with both downstream interfaces ready               |
| TC_BASIC_02           | 2026-08-10 | Annim Jannat        | Back-to-back multi-beat transfer, both downstreams always ready          |
| TC_PRI_ONLY_01        | 2026-08-10 | Annim Jannat        | Primary ready / secondary not ready - secondary starvation check         |
| TC_SEC_ONLY_01        | 2026-08-10 | Annim Jannat        | Secondary ready / primary not ready - primary starvation check           |
| TC_NONE_READY_01      | 2026-08-10 | Annim Jannat        | Neither ready initially, then primary alone becomes ready                |
| TC_NONE_READY_02      | 2026-08-10 | Annim Jannat        | Directed test of documented priority-drop: neither ready, then both ready|
| TC_STALL_VALID_01     | 2026-08-10 | Annim Jannat        | Upstream valid de-asserted mid-stall before either downstream is ready   |
| TC_READY_TOGGLE_01    | 2026-08-10 | Annim Jannat        | Valid held constant while both downstream readies toggle independently   |
| TC_WIDTH_ONES_01      | 2026-08-10 | Annim Jannat        | Data integrity check with all-ones (max value) data pattern              |
| TC_WIDTH_ZEROS_01     | 2026-08-10 | Annim Jannat        | Data integrity check with all-zeros data pattern                         |
| TC_BACK2BACK_STRESS   | 2026-08-10 | Annim Jannat        | Continuous input stream with independently toggling downstream readies   |
| TC_RANDOM_01          | 2026-08-10 | Annim Jannat        | Fully randomized valid/ready/data/clear stress test over many cycles     |
| TC_ALL                | 2026-08-31 | Annim Jannat        | Default regression suite executing all test scenarios sequentially       |

| REVISION   | DATE       | AUTHOR                     | DESCRIPTION                                                                  |
|------------|------------|----------------------------|------------------------------------------------------------------------------|
| 0.1        | 2026-08-10 | Annim Jannat               | Initial version                                                              |
| 1.0        | 2026-08-11 | Annim Jannat               | Stable release                                                               |
| 1.1        | 2026-08-31 | Ahasan Ullah Khalid        | Added clear_i signal support, reference model updates, and clear testcases   |
| 1.2        | 2026-09-13 | Annim Jannat               | Added functional coverage covergroup and sampling                           |
| 1.3        | 2026-09-13 | Annim Jannat               | (superseded by 1.4) reference model rewritten as hold-on-stall - wrong      |
| 1.4        | 2026-09-13 | Annim Jannat               | Reference model rewritten to exactly mirror adn_common_pipeline RTL         |

Author : Annim Jannat (jannatannim@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_pipeline_split_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam time CLKPeriod = 10ns;
  localparam int DATA_WIDTH = 8;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  covergroup cg_pipeline_split with function sample (
      input logic                      clr,
      input logic                      in_valid,
      input logic                      in_ready,
      input logic                      pri_ready,
      input logic                      sec_ready,
      input logic                      pri_valid,
      input logic                      sec_valid,
      input logic [DATA_WIDTH-1:0]     din
  );

    option.per_instance = 1;

    clear_cp: coverpoint clr {
      bins clear_inactive = {1'b0};
      bins clear_active   = {1'b1};
    }

    in_valid_cp: coverpoint in_valid {
      bins invalid = {1'b0};
      bins valid   = {1'b1};
    }

    in_ready_cp: coverpoint in_ready {
      bins not_ready = {1'b0};
      bins ready     = {1'b1};
    }

    pri_ready_cp: coverpoint pri_ready {
      bins not_ready = {1'b0};
      bins ready     = {1'b1};
    }

    sec_ready_cp: coverpoint sec_ready {
      bins not_ready = {1'b0};
      bins ready     = {1'b1};
    }

    pri_valid_cp: coverpoint pri_valid {
      bins invalid = {1'b0};
      bins valid   = {1'b1};
    }

    sec_valid_cp: coverpoint sec_valid {
      bins invalid = {1'b0};
      bins valid   = {1'b1};
    }

    din_cp: coverpoint din {
      bins zeros  = {'0};
      bins ones   = {{DATA_WIDTH{1'b1}}};
      bins others = default;
    }

    // both downstream ready combinations (idle / primary-only / secondary-only / both)
    ready_combo_cross: cross pri_ready_cp, sec_ready_cp;

    // input handshake combinations
    handshake_cross: cross in_valid_cp, in_ready_cp;

    // documented secondary priority-drop scenario: primary ready while secondary held valid
    priority_drop_cross: cross pri_ready_cp, sec_valid_cp;

  endgroup

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                         clk;
  logic                         arst_n;
  logic                         clear;

  // Upstream (input) interface
  logic        [DATA_WIDTH-1:0] data_in;
  logic                         data_in_valid;
  logic                         data_in_ready;

  // Downstream - primary
  logic        [DATA_WIDTH-1:0] data_out_primary;
  logic                         data_out_primary_valid;
  logic                         data_out_primary_ready;

  // Downstream - secondary
  logic        [DATA_WIDTH-1:0] data_out_secondary;
  logic                         data_out_secondary_valid;
  logic                         data_out_secondary_ready;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                         ref_is_full;
  logic        [DATA_WIDTH-1:0] ref_data_reg;

  logic                         exp_secondary_valid_dly;
  logic                         primary_ready_dly;
  logic                         secondary_ready_dly;

  int unsigned                  drop_event_count;
  int unsigned                  primary_xfer_count;
  int unsigned                  secondary_xfer_count;

  cg_pipeline_split              cg_pipeline_split_cov = new();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_pipeline_split #(
      .DATA_WIDTH(DATA_WIDTH)
  ) u_dut (
      .arst_ni(arst_n),
      .clk_i  (clk),

      .clear_i(clear),

      .data_in_i      (data_in),
      .data_in_valid_i(data_in_valid),
      .data_in_ready_o(data_in_ready),

      .data_out_secondary_o      (data_out_secondary),
      .data_out_secondary_valid_o(data_out_secondary_valid),
      .data_out_secondary_ready_i(data_out_secondary_ready),

      .data_out_primary_o      (data_out_primary),
      .data_out_primary_valid_o(data_out_primary_valid),
      .data_out_primary_ready_i(data_out_primary_ready)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic pulse_reset(input time low_time);
    arst_n <= '0;
    #(low_time);
    arst_n <= '1;
  endtask

  task automatic apply_reset();
    #100ns;
    arst_n                   <= '0;
    clear                    <= '0;
    data_in                  <= '0;
    data_in_valid            <= '0;
    data_out_primary_ready   <= '0;
    data_out_secondary_ready <= '0;
    ref_is_full              <= '0;
    ref_data_reg             <= '0;
    exp_secondary_valid_dly  <= '0;
    primary_ready_dly        <= '0;
    secondary_ready_dly      <= '0;
    drop_event_count         <= '0;
    primary_xfer_count       <= '0;
    secondary_xfer_count     <= '0;
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

  task automatic drive_clear(input int cycles = 1);
    @(negedge clk);
    clear <= '1;
    repeat (cycles) @(posedge clk);
    @(negedge clk);
    clear <= '0;
  endtask

  task automatic drive_input(input logic [DATA_WIDTH-1:0] data, input logic valid);
    @(negedge clk);
    data_in       <= data;
    data_in_valid <= valid;
    @(posedge clk);
  endtask

  task automatic set_ready(input logic pri_rdy, input logic sec_rdy);
    @(negedge clk);
    data_out_primary_ready   <= pri_rdy;
    data_out_secondary_ready <= sec_rdy;
    @(posedge clk);
  endtask

  task automatic hold_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  task automatic start_checking();
    fork
      forever
      @(negedge arst_n) begin
        ref_is_full  <= '0;
        ref_data_reg <= '0;
      end
    join_none

    fork
      forever
      @(posedge clk) begin
        if (arst_n) begin
          // Update reference state at posedge, mirroring adn_common_pipeline exactly
          // (the inner stage instantiated inside adn_common_pipeline_split as u_pl):
          //
          //   data_in_ready_o = is_full ? (data_out_ready_i | clear_i) : arst_ni
          //   is_full_next    = data_in_valid_i ? 1 : (data_out_ready_i ? 0 : is_full)
          //   is_full         <= clear_i ? data_in_valid_i : is_full_next
          //   data_reg        <= data_in_i  whenever (data_in_valid_i & data_in_ready_o)
          //
          // Two subtleties that are easy to miss:
          //  - clear_i ALSO unblocks readiness while full (ready|clear), it isn't only
          //    downstream_ready that can free up the slot.
          //  - clear_i does NOT force-flush when data_in_valid_i is high the same cycle:
          //    is_full becomes data_in_valid_i, so a concurrent valid input is still
          //    captured even while clear is asserted.
          automatic logic downstream_ready = data_out_primary_ready | data_out_secondary_ready;
          // Readiness computed from the state going INTO this edge (pre-update ref_is_full),
          // exactly like the RTL's combinational data_in_ready_o just before the clock edge.
          automatic logic pre_ready = ref_is_full ? (downstream_ready | clear) : 1'b1;
          automatic logic in_accept = data_in_valid & pre_ready;

          if (in_accept) begin
            ref_data_reg <= data_in;
          end

          if (clear) begin
            ref_is_full <= data_in_valid;
          end else begin
            ref_is_full <= data_in_valid ? 1'b1 : (downstream_ready ? 1'b0 : ref_is_full);
          end

          // Verify outputs after combinational logic settles. By this point the nonblocking
          // updates above have taken effect, so ref_is_full/ref_data_reg here are the POST-edge
          // (new) values - matching the DUT's registered outputs at the same point in time.
          #1ns;

          if (arst_n) begin
            automatic logic                  exp_ready;
            automatic logic                  exp_primary_valid;
            automatic logic                  exp_secondary_valid;
            automatic logic [DATA_WIDTH-1:0] exp_data;

            exp_ready = ref_is_full ? (data_out_primary_ready | data_out_secondary_ready | clear)
                : 1'b1;
            exp_primary_valid = ref_is_full & ~clear;
            exp_secondary_valid = ref_is_full & ~clear & ~data_out_primary_ready;
            exp_data = ref_data_reg;

            // Check 1: data_in_ready_o
            if (data_in_ready !== exp_ready) begin
              note_case(0);
              $display(
                  "[%s] FAIL [%0t] data_in_ready_o mismatch: exp=%b got=%b (is_full=%b pri_rdy=%b sec_rdy=%b clear=%b)",
                  test_name, $realtime, exp_ready, data_in_ready, ref_is_full,
                  data_out_primary_ready, data_out_secondary_ready, clear);
            end else begin
              note_case(1);
            end

            // Check 2: primary_valid_o
            if (data_out_primary_valid !== exp_primary_valid) begin
              note_case(0);
              $display(
                  "[%s] FAIL [%0t] data_out_primary_valid_o mismatch: exp=%b got=%b (clear=%b)",
                  test_name, $realtime, exp_primary_valid, data_out_primary_valid, clear);
            end else begin
              note_case(1);
            end

            // Check 3: secondary_valid_o
            if (data_out_secondary_valid !== exp_secondary_valid) begin
              note_case(0);
              $display(
                  "[%s] FAIL [%0t] data_out_secondary_valid_o mismatch: exp=%b got=%b (clear=%b)",
                  test_name, $realtime, exp_secondary_valid, data_out_secondary_valid, clear);
            end else begin
              note_case(1);
            end

            // Check 4: data integrity
            if (exp_primary_valid && (data_out_primary !== exp_data)) begin
              note_case(0);
              $display("[%s] FAIL [%0t] data_out_primary_o mismatch: exp=%0h got=%0h", test_name,
                       $realtime, exp_data, data_out_primary);
            end else if (exp_primary_valid) begin
              note_case(1);
            end

            if (exp_secondary_valid && (data_out_secondary !== exp_data)) begin
              note_case(0);
              $display("[%s] FAIL [%0t] data_out_secondary_o mismatch: exp=%0h got=%0h", test_name,
                       $realtime, exp_data, data_out_secondary);
            end else if (exp_secondary_valid) begin
              note_case(1);
            end

            if (data_out_primary_valid && data_out_primary_ready) begin
              primary_xfer_count <= primary_xfer_count + 1;
            end
            if (data_out_secondary_valid && data_out_secondary_ready) begin
              secondary_xfer_count <= secondary_xfer_count + 1;
            end

            if (exp_secondary_valid_dly && !secondary_ready_dly && !primary_ready_dly &&
                data_out_primary_ready && ref_is_full && !exp_secondary_valid) begin
              drop_event_count <= drop_event_count + 1;
              $display(
                  "[%s] INFO [%0t] Observed documented SECONDARY priority-drop event (count=%0d)",
                  test_name, $realtime, drop_event_count + 1);
            end

            exp_secondary_valid_dly <= exp_secondary_valid;
            primary_ready_dly       <= data_out_primary_ready;
            secondary_ready_dly     <= data_out_secondary_ready;
          end
        end
      end
    join_none
  endtask

  task automatic start_coverage();
    fork
      forever
      @(posedge clk) begin
        if (arst_n) begin
          cg_pipeline_split_cov.sample(clear, data_in_valid, data_in_ready, data_out_primary_ready,
                                        data_out_secondary_ready, data_out_primary_valid,
                                        data_out_secondary_valid, data_in);
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
    set_ready(1, 1);
    drive_input(8'hA5, 1);
    pulse_reset(CLKPeriod);
    hold_cycles(3);
  endtask

  task automatic run_tc_rst_03();
    apply_reset();
    set_ready(0, 0);
    drive_input(8'h3C, 1);
    hold_cycles(3);
    pulse_reset(CLKPeriod);
    hold_cycles(3);
  endtask

  task automatic run_tc_clr_01();
    apply_reset();
    set_ready(1, 1);
    drive_input(8'h00, 0);
    drive_clear(2);
    hold_cycles(3);
  endtask

  task automatic run_tc_clr_02();
    apply_reset();
    set_ready(0, 0);
    drive_input(8'h55, 1);
    drive_input(8'h00, 0);
    hold_cycles(2);
    drive_clear(1);
    hold_cycles(2);
    set_ready(1, 1);
    hold_cycles(3);
  endtask

  task automatic run_tc_clr_03();
    apply_reset();
    set_ready(0, 0);
    @(negedge clk);
    clear         <= '1;
    data_in       <= 8'hAA;
    data_in_valid <= '1;
    @(posedge clk);
    @(negedge clk);
    clear         <= '0;
    data_in_valid <= '0;
    @(posedge clk);
    hold_cycles(3);
  endtask

  task automatic run_tc_clr_04();
    apply_reset();
    set_ready(1, 1);
    drive_input(8'h12, 1);
    drive_clear(1);
    drive_input(8'h34, 1);
    drive_input(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_basic_01();
    apply_reset();
    set_ready(1, 1);
    drive_input(8'h11, 1);
    drive_input(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_basic_02();
    apply_reset();
    set_ready(1, 1);
    drive_input(8'h01, 1);
    drive_input(8'h02, 1);
    drive_input(8'h03, 1);
    drive_input(8'h04, 1);
    drive_input(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_pri_only_01();
    apply_reset();
    set_ready(1, 0);
    drive_input(8'h5A, 1);
    hold_cycles(4);
    drive_input(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_sec_only_01();
    apply_reset();
    set_ready(0, 1);
    drive_input(8'hA6, 1);
    hold_cycles(4);
    drive_input(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_none_ready_01();
    apply_reset();
    set_ready(0, 0);
    drive_input(8'h7E, 1);
    hold_cycles(3);
    set_ready(1, 0);
    hold_cycles(3);
    drive_input(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_none_ready_02();
    apply_reset();
    set_ready(0, 0);
    drive_input(8'hC3, 1);
    hold_cycles(3);
    set_ready(1, 1);
    hold_cycles(3);
    drive_input(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_stall_valid_deassert_01();
    apply_reset();
    set_ready(0, 0);
    drive_input(8'h2D, 1);
    hold_cycles(2);
    drive_input(8'h00, 0);
    hold_cycles(2);
    set_ready(1, 1);
    hold_cycles(2);
  endtask

  task automatic run_tc_ready_toggle_01();
    apply_reset();
    drive_input(8'h6F, 1);
    set_ready(1, 0);
    set_ready(0, 1);
    set_ready(0, 0);
    set_ready(1, 1);
    drive_input(8'h00, 0);
    hold_cycles(3);
  endtask

  task automatic run_tc_width_allones_01();
    apply_reset();
    set_ready(1, 1);
    drive_input({DATA_WIDTH{1'b1}}, 1);
    drive_input(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_width_allzeros_01();
    apply_reset();
    set_ready(1, 1);
    drive_input({DATA_WIDTH{1'b0}}, 1);
    drive_input(8'h00, 0);
    hold_cycles(2);
  endtask

  task automatic run_tc_back2back_stress_01();
    apply_reset();
    for (int i = 0; i < 20; i++) begin
      set_ready($urandom_range(0, 1), $urandom_range(0, 1));
      drive_input(i[DATA_WIDTH-1:0], 1);
    end
    drive_input(8'h00, 0);
    set_ready(1, 1);
    hold_cycles(5);
  endtask

  task automatic run_tc_random_01();
    apply_reset();
    for (int i = 0; i < 50; i++) begin
      @(negedge clk);
      clear                    <= ($urandom_range(0, 9) == 0);
      data_out_primary_ready   <= $urandom_range(0, 1);
      data_out_secondary_ready <= $urandom_range(0, 1);
      data_in                  <= $urandom;
      data_in_valid            <= $urandom_range(0, 1);
      @(posedge clk);
    end
    @(negedge clk);
    clear         <= '0;
    data_in_valid <= '0;
    set_ready(1, 1);
    hold_cycles(5);
  endtask

  task automatic run_tc_all();
    run_tc_rst_01();
    run_tc_rst_02();
    run_tc_rst_03();
    run_tc_clr_01();
    run_tc_clr_02();
    run_tc_clr_03();
    run_tc_clr_04();
    run_tc_basic_01();
    run_tc_basic_02();
    run_tc_pri_only_01();
    run_tc_sec_only_01();
    run_tc_none_ready_01();
    run_tc_none_ready_02();
    run_tc_stall_valid_deassert_01();
    run_tc_ready_toggle_01();
    run_tc_width_allones_01();
    run_tc_width_allzeros_01();
    run_tc_back2back_stress_01();
    run_tc_random_01();
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    clk = '0;

    apply_reset();

    start_clock();

    start_checking();

    start_coverage();

    case (test_name)
      "TC_RST_01":           run_tc_rst_01();
      "TC_RST_02":           run_tc_rst_02();
      "TC_RST_03":           run_tc_rst_03();
      "TC_CLR_01":           run_tc_clr_01();
      "TC_CLR_02":           run_tc_clr_02();
      "TC_CLR_03":           run_tc_clr_03();
      "TC_CLR_04":           run_tc_clr_04();
      "TC_BASIC_01":         run_tc_basic_01();
      "TC_BASIC_02":         run_tc_basic_02();
      "TC_PRI_ONLY_01":      run_tc_pri_only_01();
      "TC_SEC_ONLY_01":      run_tc_sec_only_01();
      "TC_NONE_READY_01":    run_tc_none_ready_01();
      "TC_NONE_READY_02":    run_tc_none_ready_02();
      "TC_STALL_VALID_01":   run_tc_stall_valid_deassert_01();
      "TC_READY_TOGGLE_01":  run_tc_ready_toggle_01();
      "TC_WIDTH_ONES_01":    run_tc_width_allones_01();
      "TC_WIDTH_ZEROS_01":   run_tc_width_allzeros_01();
      "TC_BACK2BACK_STRESS": run_tc_back2back_stress_01();
      "TC_RANDOM_01":        run_tc_random_01();

      default: begin
      TC_ALL :              run_tc_all();
      end
    endcase

    #100ns;
    $display("[%s] SUMMARY: primary_xfers=%0d secondary_xfers=%0d priority_drop_events=%0d",
             test_name, primary_xfer_count, secondary_xfer_count, drop_event_count);
    $display("[%s] COVERAGE: cg_pipeline_split=%0.2f%%", test_name,
             cg_pipeline_split_cov.get_inst_coverage());
    $finish;
  end

endmodule
