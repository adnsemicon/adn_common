/*

| TEST CASE | DATE       | AUTHOR | DESCRIPTION                                                             |
|-----------|------------|--------|-------------------------------------------------------------------------|
| TC_001    | 2026-11-01 | Annim  | Asynchronous reset assertion on both domains and initial state check    |
| TC_002    | 2026-11-01 | Annim  | Single word write and read with cross-domain synchronization            |
| TC_003    | 2026-11-01 | Annim  | Sequential burst fill to full capacity and complete drain to empty      |
| TC_004    | 2026-11-01 | Annim  | Overflow protection: write attempt when full is ignored                 |
| TC_005    | 2026-11-01 | Annim  | Underflow protection: read attempt when empty produces no spurious data |
| TC_006    | 2026-11-01 | Annim  | Asynchronous reset during active operation and clean recovery           |
| TC_007    | 2026-11-01 | Annim  | Concurrent randomized streaming write and read traffic                  |
| TC_008    | 2026-11-01 | Annim  | Back-to-back maximum throughput continuous write and read stress        |
| TC_009    | 2026-11-01 | Annim  | Boundary conditions: simultaneous operations at full and empty          |
| TC_ALL    | 2026-11-01 | Annim  | Run all test cases in sequence                                          |

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

  localparam int DATA_WIDTH  = 8;
  localparam int FIFO_SIZE   = 2;
  localparam int SYNC_STAGES = 2;
  localparam int DEPTH       = 1 << FIFO_SIZE;

  // Asynchronous clock periods with non-integer ratio
  localparam time WrClkPeriod = 7ns;
  localparam time RdClkPeriod = 4ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Write clock domain
  logic                  data_in_clk_i = 1'b0;
  logic                  data_in_arst_ni;
  logic [DATA_WIDTH-1:0] data_in_i;
  logic                  data_in_valid_i;
  logic                  data_in_ready_o;
  logic [   FIFO_SIZE:0] data_in_count_o;

  // Read clock domain
  logic                  data_out_clk_i = 1'b0;
  logic                  data_out_arst_ni;
  logic [DATA_WIDTH-1:0] data_out_o;
  logic                  data_out_valid_o;
  logic                  data_out_ready_i;
  logic [   FIFO_SIZE:0] data_out_count_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Reference queue for end-to-end scoreboard data integrity check
  logic [DATA_WIDTH-1:0] expected_q[$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // COVERAGE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  covergroup cdc_fifo_in_cov @(posedge data_in_clk_i);
    option.per_instance = 1;

    cp_in_reset: coverpoint data_in_arst_ni {
      bins reset_asserted   = {1'b0};
      bins reset_deasserted = {1'b1};
    }

    cp_in_valid: coverpoint data_in_valid_i {
      bins not_valid = {1'b0};
      bins is_valid  = {1'b1};
    }

    cp_in_ready: coverpoint data_in_ready_o {
      bins not_ready = {1'b0};
      bins is_ready  = {1'b1};
    }

    cp_in_handshake: coverpoint (data_in_valid_i && data_in_ready_o) {
      bins no_handshake = {1'b0};
      bins handshake    = {1'b1};
    }

    cp_in_count: coverpoint data_in_count_o {
      bins empty   = {0};
      bins partial = {[1 : DEPTH - 1]};
      bins full    = {DEPTH};
    }

    cp_overflow_attempt: coverpoint (data_in_valid_i && !data_in_ready_o) {
      bins overflow_blocked = {1'b1};
    }

    cross_in_valid_ready: cross cp_in_valid, cp_in_ready;
    cross_in_count_ready: cross cp_in_count, cp_in_ready {
      ignore_bins full_and_ready      = binsof(cp_in_count.full)    && binsof(cp_in_ready.is_ready);
      ignore_bins empty_and_unready   = binsof(cp_in_count.empty)   && binsof(cp_in_ready.not_ready);
      ignore_bins partial_and_unready = binsof(cp_in_count.partial) && binsof(cp_in_ready.not_ready);
    }
  endgroup

  covergroup cdc_fifo_out_cov @(posedge data_out_clk_i);
    option.per_instance = 1;

    cp_out_reset: coverpoint data_out_arst_ni {
      bins reset_asserted   = {1'b0};
      bins reset_deasserted = {1'b1};
    }

    cp_out_valid: coverpoint data_out_valid_o {
      bins not_valid = {1'b0};
      bins is_valid  = {1'b1};
    }

    cp_out_ready: coverpoint data_out_ready_i {
      bins not_ready = {1'b0};
      bins is_ready  = {1'b1};
    }

    cp_out_handshake: coverpoint (data_out_valid_o && data_out_ready_i) {
      bins no_handshake = {1'b0};
      bins handshake    = {1'b1};
    }

    cp_out_count: coverpoint data_out_count_o {
      bins empty   = {0};
      bins partial = {[1 : DEPTH - 1]};
      bins full    = {DEPTH};
    }

    cp_underflow_attempt: coverpoint (!data_out_valid_o && data_out_ready_i) {
      bins underflow_blocked = {1'b1};
    }

    cross_out_valid_ready: cross cp_out_valid, cp_out_ready;
    cross_out_count_valid: cross cp_out_count, cp_out_valid {
      ignore_bins empty_and_valid     = binsof(cp_out_count.empty)   && binsof(cp_out_valid.is_valid);
      ignore_bins full_and_invalid    = binsof(cp_out_count.full)    && binsof(cp_out_valid.not_valid);
      ignore_bins partial_and_invalid = binsof(cp_out_count.partial) && binsof(cp_out_valid.not_valid);
    }
  endgroup

  covergroup cdc_fifo_data_cov with function sample(logic [DATA_WIDTH-1:0] data_val);
    option.per_instance = 1;

    cp_data_pattern: coverpoint data_val {
      bins zeros   = {'0};
      bins ones    = {'1};
      bins alt_aa  = {8'hAA};
      bins alt_55  = {8'h55};
      bins others  = default;
    }
  endgroup

  cdc_fifo_in_cov   in_cov_inst   = new();
  cdc_fifo_out_cov  out_cov_inst  = new();
  cdc_fifo_data_cov data_cov_inst = new();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_cdc_fifo #(
      .DATA_WIDTH (DATA_WIDTH),
      .FIFO_SIZE  (FIFO_SIZE),
      .SYNC_STAGES(SYNC_STAGES)
  ) dut (
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

  // Independent free-running clock generators
  initial forever #(WrClkPeriod / 2.0) data_in_clk_i  = ~data_in_clk_i;
  initial forever #(RdClkPeriod / 2.0) data_out_clk_i = ~data_out_clk_i;

  // Scoreboard write capture
  always @(posedge data_in_clk_i or negedge data_in_arst_ni) begin
    if (!data_in_arst_ni) begin
      expected_q.delete();
    end else if (data_in_valid_i && data_in_ready_o) begin
      expected_q.push_back(data_in_i);
      data_cov_inst.sample(data_in_i);
    end
  end

  // Scoreboard read checking
  always @(posedge data_out_clk_i) begin
    if (data_out_arst_ni && data_out_valid_o && data_out_ready_i) begin
      if (expected_q.size() > 0) begin
        automatic logic [DATA_WIDTH-1:0] exp = expected_q.pop_front();
        if (data_out_o === exp) begin
          note_case(1'b1);
          if (debug) begin
            $display("[PASS] Read data match: exp=0x%02h got=0x%02h [%0t]", exp, data_out_o, $realtime);
          end
        end else begin
          $display("[FAIL] Read data mismatch: exp=0x%02h got=0x%02h [%0t]", exp, data_out_o, $realtime);
          note_case(1'b0);
        end
      end else begin
        $display("[FAIL] Unexpected read when scoreboard queue is empty [%0t]", $realtime);
        note_case(1'b0);
      end
    end
  end

  // Structural protocol checks
  always @(posedge data_in_clk_i) begin
    if (data_in_arst_ni && (data_in_count_o == DEPTH)) begin
      note_case(data_in_ready_o == 1'b0);
    end
  end

  always @(posedge data_out_clk_i) begin
    if (data_out_arst_ni && (data_out_count_o == '0)) begin
      note_case(data_out_valid_o == 1'b0);
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Applies clean asynchronous reset across both clock domains
  task automatic apply_reset();
    data_in_arst_ni  = 1'b0;
    data_out_arst_ni = 1'b0;
    data_in_i        = '0;
    data_in_valid_i  = 1'b0;
    data_out_ready_i = 1'b0;

    repeat (3) @(posedge data_in_clk_i);
    repeat (3) @(posedge data_out_clk_i);

    data_in_arst_ni  = 1'b1;
    data_out_arst_ni = 1'b1;

    repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
  endtask

  // Blocking single-word write (guaranteed acceptance)
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

  // Non-blocking single-cycle write attempt
  task automatic try_write(input logic [DATA_WIDTH-1:0] value);
    @(negedge data_in_clk_i);
    data_in_i       = value;
    data_in_valid_i = 1'b1;
    @(posedge data_in_clk_i);
    @(negedge data_in_clk_i);
    data_in_valid_i = 1'b0;
  endtask

  // Blocking single-word read (guaranteed pop)
  task automatic read_word(output logic [DATA_WIDTH-1:0] value);
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b1;
    do begin
      @(posedge data_out_clk_i);
    end while (!data_out_valid_o);
    value = data_out_o;
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b0;
  endtask

  // Non-blocking single-cycle read attempt
  task automatic try_read();
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b1;
    @(posedge data_out_clk_i);
    @(negedge data_out_clk_i);
    data_out_ready_i = 1'b0;
  endtask

  // TC_001: Reset assertion and de-assertion verification
  task automatic tc_reset();
    apply_reset();
    note_case(data_in_ready_o == 1'b1);
    note_case(data_out_valid_o == 1'b0);
    note_case(data_in_count_o == '0);
    note_case(data_out_count_o == '0);
  endtask

  // TC_002: Single word write and read with cross-domain synchronization
  task automatic tc_single_transfer();
    automatic logic [DATA_WIDTH-1:0] patterns[4] = '{8'h00, 8'h55, 8'hAA, 8'hFF};
    logic [DATA_WIDTH-1:0] rd_data;
    apply_reset();

    for (int p = 0; p < 4; p++) begin
      write_word(patterns[p]);
      repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);

      note_case(data_out_valid_o == 1'b1);
      read_word(rd_data);
      note_case(rd_data === patterns[p]);

      repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
      note_case(data_in_count_o == '0);
      note_case(data_out_count_o == '0);
      note_case(data_out_valid_o == 1'b0);
    end
  endtask

  // TC_003: Sequential burst fill to full capacity and complete drain to empty
  task automatic tc_burst_fill_drain();
    logic [DATA_WIDTH-1:0] rd_data;
    apply_reset();

    for (int i = 0; i < DEPTH; i++) begin
      write_word(i[DATA_WIDTH-1:0] + 8'h10);
    end

    note_case(data_in_ready_o == 1'b0);
    note_case(data_in_count_o == DEPTH);

    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    note_case(data_out_count_o == DEPTH);
    note_case(data_out_valid_o == 1'b1);

    for (int i = 0; i < DEPTH; i++) begin
      read_word(rd_data);
    end

    note_case(data_out_valid_o == 1'b0);
    note_case(data_out_count_o == '0);

    repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
    note_case(data_in_ready_o == 1'b1);
    note_case(data_in_count_o == '0);
  endtask

  // TC_004: Overflow protection: write attempt when full is ignored
  task automatic tc_overflow();
    logic [DATA_WIDTH-1:0] rd_data;
    apply_reset();

    for (int i = 0; i < DEPTH; i++) begin
      write_word(i[DATA_WIDTH-1:0] + 8'h20);
    end

    note_case(data_in_ready_o == 1'b0);
    try_write(8'hFF); // Attempt extra write while full
    note_case(data_in_count_o == DEPTH);

    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    for (int i = 0; i < DEPTH; i++) begin
      read_word(rd_data);
      note_case(rd_data === (i[DATA_WIDTH-1:0] + 8'h20));
    end

    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    note_case(data_out_valid_o == 1'b0);
  endtask

  // TC_005: Underflow protection: read attempt when empty produces no spurious data
  task automatic tc_underflow();
    apply_reset();
    note_case(data_out_valid_o == 1'b0);

    try_read(); // Attempt read while empty
    note_case(data_out_count_o == '0);
    note_case(data_out_valid_o == 1'b0);
  endtask

  // TC_006: Asynchronous reset during active operation and clean recovery
  task automatic tc_mid_transfer_reset();
    logic [DATA_WIDTH-1:0] rd_data;
    apply_reset();

    write_word(8'h11);
    write_word(8'h22);

    // Asynchronously assert reset mid-transfer
    data_in_arst_ni  = 1'b0;
    data_out_arst_ni = 1'b0;
    repeat (2) @(posedge data_in_clk_i);
    repeat (2) @(posedge data_out_clk_i);
    data_in_arst_ni  = 1'b1;
    data_out_arst_ni = 1'b1;
    repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);

    note_case(data_in_count_o == '0);
    note_case(data_out_count_o == '0);
    note_case(data_out_valid_o == 1'b0);
    note_case(data_in_ready_o == 1'b1);

    // Verify normal operation resumes cleanly
    write_word(8'h55);
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    read_word(rd_data);
    note_case(rd_data === 8'h55);
  endtask

  // TC_007: Concurrent randomized streaming write and read traffic
  task automatic tc_concurrent_random();
    localparam int NUM_TRANSFERS = 100;
    apply_reset();

    fork
      begin : wr_stream
        for (int i = 0; i < NUM_TRANSFERS; i++) begin
          automatic logic [DATA_WIDTH-1:0] val = $urandom;
          write_word(val);
          repeat ($urandom_range(0, 3)) @(posedge data_in_clk_i);
        end
      end
      begin : rd_stream
        for (int i = 0; i < NUM_TRANSFERS; i++) begin
          automatic logic [DATA_WIDTH-1:0] val;
          read_word(val);
          repeat ($urandom_range(0, 3)) @(posedge data_out_clk_i);
        end
      end
    join

    repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    note_case(data_in_count_o == '0);
    note_case(data_out_count_o == '0);
    note_case(data_out_valid_o == 1'b0);
  endtask

  // TC_008: Back-to-back maximum throughput continuous write and read stress
  task automatic tc_stress_back_to_back();
    localparam int NUM_STRESS = 150;
    apply_reset();

    fork
      begin : stress_writer
        for (int i = 0; i < NUM_STRESS; i++) begin
          write_word(i[DATA_WIDTH-1:0]);
        end
      end
      begin : stress_reader
        for (int i = 0; i < NUM_STRESS; i++) begin
          automatic logic [DATA_WIDTH-1:0] val;
          read_word(val);
        end
      end
    join

    repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    note_case(data_in_count_o == '0);
    note_case(data_out_count_o == '0);
    note_case(data_out_valid_o == 1'b0);
  endtask

  // TC_009: Boundary conditions: simultaneous operations at full and empty
  task automatic tc_corner_cases();
    logic [DATA_WIDTH-1:0] val;
    apply_reset();

    // Fill to full
    for (int i = 0; i < DEPTH; i++) begin
      write_word(i[DATA_WIDTH-1:0]);
    end

    // Simultaneous write at full and read freeing a slot
    fork
      write_word(8'hE1);
      read_word(val);
    join

    // Drain remaining
    for (int i = 0; i < DEPTH; i++) begin
      read_word(val);
    end

    // Simultaneous read at empty and write filling a slot
    fork
      read_word(val);
      write_word(8'hE2);
    join
    note_case(val === 8'hE2);

    repeat (SYNC_STAGES + 2) @(posedge data_in_clk_i);
    repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    note_case(data_in_count_o == '0);
    note_case(data_out_count_o == '0);
  endtask

  // Runs all test cases in sequence
  task automatic run_all();
    tc_reset();
    tc_single_transfer();
    tc_burst_fill_drain();
    tc_overflow();
    tc_underflow();
    tc_mid_transfer_reset();
    tc_concurrent_random();
    tc_stress_back_to_back();
    tc_corner_cases();
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin // main initial
    automatic int iterations;
    iterations = (test_count > 0) ? test_count : 1;

    for (int iter = 0; iter < iterations; iter++) begin
      case (test_name)
        "TC_001", "TC_RST_01":          tc_reset();
        "TC_002", "TC_RD_01", "TC_WR_01": tc_single_transfer();
        "TC_003", "TC_FULL_01", "TC_EMPTY_01": tc_burst_fill_drain();
        "TC_004", "TC_WR_02":          tc_overflow();
        "TC_005", "TC_RD_02":          tc_underflow();
        "TC_006", "TC_RST_02", "TC_RST_03": tc_mid_transfer_reset();
        "TC_007", "TC_CDC_01", "TC_CDC_02", "TC_STR_02": tc_concurrent_random();
        "TC_008", "TC_STR_01":          tc_stress_back_to_back();
        "TC_009", "TC_ROB_01", "TC_ROB_02": tc_corner_cases();
        "TC_ALL", "all", "default":     run_all();
        default: begin
          $display("Unrecognized test name '%s', running TC_ALL", test_name);
          run_all();
        end
      endcase
    end

    #100ns;
    $finish;
  end

endmodule
