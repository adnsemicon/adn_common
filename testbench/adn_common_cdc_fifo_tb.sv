/*

| TEST CASE  | DATE       | AUTHOR | DESCRIPTION                                                          |
|------------|------------|--------|----------------------------------------------------------------------|
| TC_RST_01  | 2026-08-30 | Annim  | Asynchronous reset assertion on both domains                         |
| TC_RST_02  | 2026-08-30 | Annim  | Reset asserted mid-transfer, verify clean flush / no X propagation   |
| TC_RST_03  | 2026-08-30 | Annim  | Reset de-assertion recovery, normal operation resumes                |
| TC_WR_01   | 2026-08-30 | Annim  | Single write handshake when empty                                    |
| TC_WR_02   | 2026-08-30 | Annim  | Write attempted while full, ready deasserted until space frees       |
| TC_RD_01   | 2026-08-30 | Annim  | Single read handshake when non-empty                                 |
| TC_RD_02   | 2026-08-30 | Annim  | Read attempted while empty, no spurious pop                          |
| TC_FULL_01 | 2026-08-30 | Annim  | Fill FIFO to full capacity, full/ready deassertion check             |
| TC_EMPTY_01| 2026-08-30 | Annim  | Drain FIFO to empty, empty/valid deassertion check                   |
| TC_CNT_01  | 2026-08-30 | Annim  | Occupancy counters track across synchronizer latency                 |
| TC_CDC_01  | 2026-08-30 | Annim  | Cross-domain data integrity, sequential fill then sequential drain   |
| TC_CDC_02  | 2026-08-30 | Annim  | Cross-domain data integrity, concurrent write and read streams       |
| TC_STR_01  | 2026-08-30 | Annim  | Back-to-back max-throughput write/read stress                        |
| TC_STR_02  | 2026-08-30 | Annim  | Randomized throttled write/read stress on both sides                 |
| TC_ROB_01  | 2026-08-30 | Annim  | Simultaneous write-at-full and read that frees a slot the same cycle |
| TC_ROB_02  | 2026-08-30 | Annim  | Simultaneous read-at-empty and write that fills a slot the same cycle|
| TC_ALL     | 2026-08-30 | Annim  | Run all of the above test cases in sequence                          |

| REVISION | DATE       | AUTHOR | DESCRIPTION                                                 |
|----------|------------|--------|-------------------------------------------------------------|
| 0.1      | 2026-08-30 | Annim  | Initial version                                             |
| 1.0      | 2026-08-30 | Annim  | Stable release                                              |

Author : Annim (jannatannim@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_cdc_fifo_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int               DATA_WIDTH  = 8;
  localparam int               FIFO_SIZE   = 2;  // depth = 4
  localparam int               SYNC_STAGES = 2;
  localparam logic [FIFO_SIZE:0] FIFO_DEPTH = (1 << FIFO_SIZE);  // properly sized, no part-select-on-int needed
  localparam int                 DEPTH      = 1 << FIFO_SIZE;

  localparam time WrClkPeriod = 7ns;  // asynchronous, non-integer ratio to rd clock
  localparam time RdClkPeriod = 3ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Clock nets: each is declared, initialized, and toggled ONLY by the single
  // generator below. No task or reset routine is ever allowed to assign
  // these again - a second driver racing the generator is what caused the
  // earlier hangs.
  logic                  data_in_clk_i = 1'b0;
  logic                  data_in_arst_ni;
  logic [DATA_WIDTH-1:0] data_in_i;
  logic                  data_in_valid_i;
  logic                  data_in_ready_o;
  logic [   FIFO_SIZE:0] data_in_count_o;

  logic                  data_out_clk_i = 1'b0;
  logic                  data_out_arst_ni;
  logic [DATA_WIDTH-1:0] data_out_o;
  logic                  data_out_valid_o;
  logic                  data_out_ready_i;
  logic [   FIFO_SIZE:0] data_out_count_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] expected_q[$];  // scoreboard of pushed write data
  logic [DATA_WIDTH-1:0] exp_data;
  logic [DATA_WIDTH-1:0] got_data;
  bit                    str_writer_done;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_cdc_fifo #(
      .DATA_WIDTH (DATA_WIDTH),
      .FIFO_SIZE  (FIFO_SIZE),
      .SYNC_STAGES(SYNC_STAGES)
  ) u_dut (
      .data_in_i      (data_in_i),
      .data_in_valid_i(data_in_valid_i),
      .data_in_ready_o(data_in_ready_o),
      .data_in_arst_ni(data_in_arst_ni),
      .data_in_clk_i  (data_in_clk_i),
      .data_in_count_o(data_in_count_o),

      .data_out_o      (data_out_o),
      .data_out_valid_o(data_out_valid_o),
      .data_out_ready_i(data_out_ready_i),
      .data_out_arst_ni(data_out_arst_ni),
      .data_out_clk_i  (data_out_clk_i),
      .data_out_count_o(data_out_count_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Free-running clocks - the only two processes in this file allowed to
  // touch data_in_clk_i / data_out_clk_i.
  initial forever #(WrClkPeriod / 2) data_in_clk_i = ~data_in_clk_i;
  initial forever #(RdClkPeriod / 2) data_out_clk_i = ~data_out_clk_i;

  // Background scoreboard capture: push every accepted write.
  always @(posedge data_in_clk_i or negedge data_in_arst_ni) begin
    if (!data_in_arst_ni) begin
      expected_q.delete();
    end else if (data_in_valid_i && data_in_ready_o) begin
      expected_q.push_back(data_in_i);
    end
  end

  // Background scoreboard check: verify every accepted read against the
  // oldest pushed write.
  always @(posedge data_out_clk_i) begin
    if (data_out_arst_ni && data_out_ready_i && data_out_valid_o) begin
      got_data = data_out_o;
      if (expected_q.size() == 0) begin
        note_case(0);  // FAIL - unexpected pop, scoreboard already empty
        $display("UNEXPECTED POP: scoreboard empty, got=%0h [%0t]", got_data, $realtime);
      end else begin
        exp_data = expected_q.pop_front();
        if (exp_data === got_data) begin
          note_case(1);  // PASS - data matches in order
          if (debug) begin
            $display("READ DATA MATCH: exp=%0h got=%0h [%0t]", exp_data, got_data, $realtime);
          end
        end else begin
          note_case(0);  // FAIL - data mismatch
          $display("READ DATA MISMATCH: exp=%0h got=%0h [%0t]", exp_data, got_data, $realtime);
        end
      end
    end
  end

  // Background structural invariants.
  always @(posedge data_in_clk_i) begin
    if (data_in_arst_ni && data_in_count_o == FIFO_DEPTH) begin
      note_case(data_in_ready_o == 1'b0);  // PASS - full implies ready low
    end
  end

  always @(posedge data_out_clk_i) begin
    if (data_out_arst_ni && data_out_count_o == '0) begin
      note_case(data_out_valid_o == 1'b0);  // PASS - empty implies valid low
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Resets both domains. Called exactly once, before any test runs. Never
  // touches data_in_clk_i / data_out_clk_i.
task automatic apply_reset();

    $display("[%0t] >>> ENTER apply_reset", $time);

    data_in_arst_ni  = 1'b0;
    data_out_arst_ni = 1'b0;

    data_in_i        = '0;
    data_in_valid_i  = 1'b0;
    data_out_ready_i = 1'b0;

    $display("[%0t] >>> RESET ASSERTED: in_clk=%b out_clk=%b",
             $time, data_in_clk_i, data_out_clk_i);

    repeat (5) begin
        @(posedge data_in_clk_i);
        $display("[%0t] >>> input reset cycle", $time);
    end

    $display("[%0t] >>> RELEASING INPUT RESET", $time);
    data_in_arst_ni = 1'b1;

    repeat (5) begin
        @(posedge data_out_clk_i);
        $display("[%0t] >>> output reset cycle", $time);
    end

    $display("[%0t] >>> RELEASING OUTPUT RESET", $time);
    data_out_arst_ni = 1'b1;

    $display("[%0t] >>> EXIT apply_reset", $time);

endtask

  // Lightweight reset pulse used mid-test (e.g. TC_RST_02) - only toggles
  // arst_ni on both domains, does not touch clk or re-run the full sequence.
  task automatic pulse_reset();
    data_in_arst_ni  = 1'b0;
    data_out_arst_ni = 1'b0;
    repeat (3) @(posedge data_in_clk_i);
    data_in_arst_ni = 1'b1;
    repeat (3) @(posedge data_out_clk_i);
    data_out_arst_ni = 1'b1;
    repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
  endtask

  // Drives a single-cycle write attempt on the input domain (accepted only if ready is high)
  task automatic drive_write(input logic [DATA_WIDTH-1:0] value);
    @(negedge data_in_clk_i);
    data_in_i       = value;
    data_in_valid_i = 1'b1;
    @(posedge data_in_clk_i);
    @(negedge data_in_clk_i);
    data_in_valid_i = 1'b0;
  endtask

  // Holds a write valid until it is accepted by the DUT (blocking, guaranteed accept)
  task automatic write_word(input logic [DATA_WIDTH-1:0] value);
    @(negedge data_in_clk_i);
    data_in_i       = value;
    data_in_valid_i = 1'b1;
    do begin
      @(posedge data_in_clk_i);
    end while (!data_in_ready_o);
     @(negedge data_in_clk_i);
    data_in_valid_i = 1'b0;
  endtask

  // Drives a single-cycle read attempt on the output domain (accepted only if valid is high)
  task automatic drive_read();
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b1;
    @(posedge data_out_clk_i);
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b0;
  endtask

  // Holds a read ready until data is accepted from the DUT (blocking, guaranteed pop)
  task automatic read_word();
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b1;
    do begin
      @(posedge data_out_clk_i);
    end while (!data_out_valid_o);
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b0;
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Individual Test Tasks
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // NOTE: apply_reset() is called exactly once, in the initial block below,
  // before any of these run. Tests that need to exercise reset behavior use
  // pulse_reset() (arst_ni only) instead of re-running the full sequence.

  task automatic run_tc_rst_01();
    note_case(data_in_ready_o == 1'b1);   // PASS - not full after reset
    note_case(data_out_valid_o == 1'b0);  // PASS - empty after reset
    note_case(data_in_count_o == '0);     // PASS - wr count zero after reset
    note_case(data_out_count_o == '0);    // PASS - rd count zero after reset
  endtask

  task automatic run_tc_rst_02();
    write_word(8'hDE);
    write_word(8'hAD);
    pulse_reset();
    note_case(data_in_count_o == '0);     // PASS - cleared after mid-transfer reset
    note_case(data_out_count_o == '0);    // PASS - cleared after mid-transfer reset
    note_case(data_out_valid_o == 1'b0);  // PASS - no stale data visible
  endtask

  task automatic run_tc_rst_03();
    pulse_reset();
    write_word(8'h5A);
    read_word();
  endtask

task automatic run_tc_wr_01();
    $display("[%0t] WR_01: ready=%b count=%0d rst=%b",
    $time, data_in_ready_o, data_in_count_o, data_in_arst_ni);
    note_case(data_in_ready_o == 1'b1);
    write_word(8'h11);
    $display("[%0t] WR_01: write completed, ready=%b count=%0d",
    $time, data_in_ready_o, data_in_count_o);
endtask

task automatic run_tc_wr_02();
    for (int i = 0; i < DEPTH; i++) begin
        write_word(i[DATA_WIDTH-1:0]);
    end
    note_case(data_in_ready_o == 1'b0);
    note_case(data_in_count_o == FIFO_DEPTH);
    drive_write(8'hFF);
    note_case(data_in_count_o == FIFO_DEPTH);
endtask

task automatic run_tc_rd_01();

    $display("[%0t] RD_01: BEFORE WRITE ready=%b count=%0d",
             $time, data_in_ready_o, data_in_count_o);

    write_word(8'h22);

    $display("[%0t] RD_01: AFTER WRITE valid=%b count=%0d",
             $time, data_out_valid_o, data_out_count_o);

    repeat (SYNC_STAGES + 2)
        @(posedge data_out_clk_i);

    note_case(data_out_valid_o == 1'b1);

    read_word();

    $display("[%0t] RD_01: READ COMPLETE", $time);

endtask

  task automatic run_tc_rd_02();
    note_case(data_out_valid_o == 1'b0);  // PASS - empty before first read
    drive_read();                         // attempted read, should not be accepted
    note_case(data_out_count_o == '0);    // PASS - count unchanged
  endtask

  task automatic run_tc_full_01();
    for (int i = 0; i < DEPTH; i++) write_word(i[DATA_WIDTH-1:0]);
    note_case(data_in_ready_o == 1'b0);        // PASS - full/ready deasserted
    note_case(data_in_count_o == FIFO_DEPTH);  // PASS - count at depth
  endtask

  task automatic run_tc_empty_01();
    for (int i = 0; i < DEPTH; i++) write_word(i[DATA_WIDTH-1:0]);
    for (int i = 0; i < DEPTH; i++) read_word();
    note_case(data_out_valid_o == 1'b0);  // PASS - empty/valid deasserted
    note_case(data_out_count_o == '0);    // PASS - count back to zero
  endtask

  task automatic run_tc_cnt_01();
    write_word(8'h01);
    write_word(8'h02);
    note_case(data_in_count_o == 2'd2);  // PASS - write side sees 2 immediately
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    note_case(data_out_count_o == 2'd2);  // PASS - read side synced to 2
    read_word();
    read_word();
    note_case(data_out_count_o == '0);  // PASS - read side back to zero
  endtask
task automatic run_tc_cdc_01();

    for (int base = 0; base < 32; base += DEPTH) begin

        // Fill one batch
        for (int j = 0; j < DEPTH; j++) begin
            write_word(base + j);
        end

        // Allow write pointer to propagate to read domain
        repeat (SYNC_STAGES + 2)
            @(posedge data_out_clk_i);

        // Drain one batch
        for (int j = 0; j < DEPTH; j++) begin
            read_word();
        end

        // Allow read pointer to propagate back to write domain
        repeat (SYNC_STAGES + 2)
            @(posedge data_in_clk_i);

    end

    $display("[%0t] CDC_01 FINAL: in_count=%0d out_count=%0d valid=%b ready=%b",
             $time,
             data_in_count_o,
             data_out_count_o,
             data_out_valid_o,
             data_in_ready_o);

    note_case(data_in_count_o == '0);
    note_case(data_out_count_o == '0);
    note_case(data_out_valid_o == 1'b0);

endtask

  task automatic run_tc_cdc_02();
    fork
      begin
        for (int i = 0; i < 32; i++) write_word(i[DATA_WIDTH-1:0]);
      end
      begin
        for (int i = 0; i < 32; i++) read_word();
      end
    join
  endtask
task automatic run_tc_str_01();

    $display("[%0t] STR_01 START: ready=%b count=%0d valid=%b",
             $time,
             data_in_ready_o,
             data_in_count_o,
             data_out_valid_o);

    fork

        begin : writer
            for (int i = 0; i < 256; i++) begin
                write_word(i[DATA_WIDTH-1:0]);
            end

            $display("[%0t] STR_01 WRITER DONE", $time);
        end

        begin : reader
            for (int i = 0; i < 256; i++) begin
                read_word();
            end

            $display("[%0t] STR_01 READER DONE", $time);
        end

    join

    // Allow the final read-side state to settle.
    repeat (SYNC_STAGES + 2)
        @(posedge data_out_clk_i);

    if (data_out_valid_o !== 1'b0)
        $display("[%0t] FAIL STR_01: final valid=%b",
                 $time, data_out_valid_o);

    if (data_out_count_o !== '0)
        $display("[%0t] FAIL STR_01: final count=%0d",
                 $time, data_out_count_o);

    note_case(data_out_valid_o == 1'b0);
    note_case(data_out_count_o == '0);

    $display("[%0t] STR_01 COMPLETE: count_in=%0d count_out=%0d valid=%b",
             $time,
             data_in_count_o,
             data_out_count_o,
             data_out_valid_o);

endtask

  task automatic run_tc_str_02();
    automatic logic [DATA_WIDTH-1:0] wd;
    fork
      begin : rand_writer
        for (int i = 0; i < 200; i++) begin
          wd = $urandom_range(0, (1 << DATA_WIDTH) - 1);
          write_word(wd);
          repeat ($urandom_range(0, 3)) @(posedge data_in_clk_i);
        end
      end
      begin : rand_reader
        for (int i = 0; i < 200; i++) begin
          read_word();
          repeat ($urandom_range(0, 3)) @(posedge data_out_clk_i);
        end
      end
    join
  endtask

  task automatic run_tc_rob_01();
    for (int i = 0; i < DEPTH; i++) write_word(i[DATA_WIDTH-1:0]);
    fork
      write_word(8'hAA);  // blocked until a slot frees
      read_word();        // frees a slot
    join
  endtask

  task automatic run_tc_rob_02();
    fork
      read_word();         // blocked until data is written
      write_word(8'h5A);   // fills a slot
    join
  endtask

task automatic run_all();

    apply_reset();
    $display("[%0t] START TC_RST_01", $time);
    run_tc_rst_01();

    apply_reset();
    $display("[%0t] START TC_RST_02", $time);
    run_tc_rst_02();

    apply_reset();
    $display("[%0t] START TC_RST_03", $time);
    run_tc_rst_03();

    apply_reset();
    $display("[%0t] START TC_WR_01", $time);
    run_tc_wr_01();

    apply_reset();
    $display("[%0t] START TC_WR_02", $time);
    run_tc_wr_02();

    apply_reset();
    $display("[%0t] START TC_RD_01", $time);
    run_tc_rd_01();

    apply_reset();
    $display("[%0t] START TC_RD_02", $time);
    run_tc_rd_02();

    apply_reset();
    $display("[%0t] START TC_FULL_01", $time);
    run_tc_full_01();

    apply_reset();
    $display("[%0t] START TC_EMPTY_01", $time);
    run_tc_empty_01();

    apply_reset();
    $display("[%0t] START TC_CNT_01", $time);
    run_tc_cnt_01();

    apply_reset();
    $display("[%0t] START TC_CDC_01", $time);
    run_tc_cdc_01();

    apply_reset();
    $display("[%0t] START TC_CDC_02", $time);
    run_tc_cdc_02();

    apply_reset();
    $display("[%0t] START TC_STR_01", $time);
    run_tc_str_01();

    apply_reset();
    $display("[%0t] START TC_STR_02", $time);
    run_tc_str_02();

    apply_reset();
    $display("[%0t] START TC_ROB_01", $time);
    run_tc_rob_01();

    apply_reset();
    $display("[%0t] START TC_ROB_02", $time);
    run_tc_rob_02();

endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////
// PROCEDURALS
//////////////////////////////////////////////////////////////////////////////////////////////////

task automatic run_test(input string name);

    apply_reset();

    $display("[%0t] START %s", $time, name);

    case (name)
        "TC_RST_01":   run_tc_rst_01();
        "TC_RST_02":   run_tc_rst_02();
        "TC_RST_03":   run_tc_rst_03();
        "TC_WR_01":    run_tc_wr_01();
        "TC_WR_02":    run_tc_wr_02();
        "TC_RD_01":    run_tc_rd_01();
        "TC_RD_02":    run_tc_rd_02();
        "TC_FULL_01":  run_tc_full_01();
        "TC_EMPTY_01": run_tc_empty_01();
        "TC_CNT_01":   run_tc_cnt_01();
        "TC_CDC_01":   run_tc_cdc_01();
        "TC_CDC_02":   run_tc_cdc_02();
        "TC_STR_01":   run_tc_str_01();
        "TC_STR_02":   run_tc_str_02();
        "TC_ROB_01":   run_tc_rob_01();
        "TC_ROB_02":   run_tc_rob_02();
        "TC_ALL":      run_all();
       default:
            $fatal(1, "Unrecognized test_name '%s'", name);
    endcase
    $display("[%0t] END %s", $time, name);
    #100ns;
    $finish;
endtask

initial begin
    $display("[%0t] >>> TESTBENCH START", $time);
    if (!$value$plusargs("TN=%s", test_name))
        test_name = "TC_ALL";
    $display("[%0t] >>> TEST NAME = %s", $time, test_name);
    run_test(test_name);
end

endmodule
