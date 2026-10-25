/*

| TEST CASE | DATE       | AUTHOR                     | DESCRIPTION                                              |
|-----------|------------|----------------------------|----------------------------------------------------------|
| TC_001    | 2026-07-28 | MD Sakhawat Hossain Sabbir | Basic write/read sequence                                |
| TC_002    | 2026-07-28 | MD Sakhawat Hossain Sabbir | Full flag assertion when FIFO is filled                  |
| TC_003    | 2026-07-28 | MD Sakhawat Hossain Sabbir | Empty flag assertion when FIFO is drained                |
| TC_004    | 2026-07-29 | MD Sakhawat Hossain Sabbir | Simultaneous read/write operation                        |
| TC_005    | 2026-07-29 | MD Sakhawat Hossain Sabbir | Randomized traffic stress test                           |
| TC_006    | 2026-07-29 | MD Sakhawat Hossain Sabbir | Overflow handling when writing to a full FIFO            |
| TC_007    | 2026-07-30 | MD Sakhawat Hossain Sabbir | Data integrity across multiple write/read cycles         |
| TC_008    | 2026-07-30 | MD Sakhawat Hossain Sabbir | Underflow handling on an empty FIFO                      |
| TC_009    | 2026-07-30 | MD Sakhawat Hossain Sabbir | Reset during active operation                            |
| TC_010    | 2026-07-30 | MD Sakhawat Hossain Sabbir | Simultaneous read/write on an empty FIFO                 |
| TC_011    | 2026-07-30 | MD Sakhawat Hossain Sabbir | Simultaneous read/write on a full FIFO                   |

| REVISION | DATE       | AUTHOR                     | DESCRIPTION                                               |
|----------|------------|----------------------------|-----------------------------------------------------------|
| 0.1      | 2026-07-30 | MD Sakhawat Hossain Sabbir | Initial version                             |
| 1.0      | 2026-07-30 | MD Sakhawat Hossain Sabbir | Stable release                              |

Author : MD Sakhawat Hossain Sabbir (sabbirone939@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_fifo_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  parameter DATA_WIDTH = 32;
  parameter DEPTH = 16;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                  clk_i;
  logic                  rst_ni;

  logic                  wr_en_i;
  logic                  rd_en_i;
  logic [DATA_WIDTH-1:0] data_i;

  logic [DATA_WIDTH-1:0] data_o;
  logic                  full_o;
  logic                  empty_o;
  logic                  valid_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] ref_fifo     [$];
  int                    error_count;
  int                    error_before;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_fifo #(
      .DATA_WIDTH(DATA_WIDTH),
      .DEPTH(DEPTH)
  ) dut (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .wr_en_i(wr_en_i),
      .rd_en_i(rd_en_i),
      .data_i (data_i),
      .data_o (data_o),
      .full_o (full_o),
      .empty_o(empty_o),
      .valid_o(valid_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic model_write(input logic [DATA_WIDTH-1:0] data);
    ref_fifo.push_back(data);
  endtask

  task automatic model_read();

    logic [DATA_WIDTH-1:0] expected;

    assert (ref_fifo.size() > 0)
    else $fatal(1, "Reference FIFO underflow");

    expected = ref_fifo.pop_front();

    if (data_o !== expected) begin

      tb_error($sformatf("FIFO DATA ERROR: Expected = 0x%08h, Got = 0x%08h", expected, data_o));

    end else begin

      if (debug) $display("FIFO DATA MATCH: Expected = 0x%08h, Got = 0x%08h", expected, data_o);

    end

  endtask

  task automatic fifo_write(input logic [DATA_WIDTH-1:0] data);
    @(posedge clk_i);

    if (!full_o) begin
      wr_en_i = 1;
      data_i  = data;
      model_write(data);
    end else begin
      $display("WRITE BLOCKED : FIFO FULL");
    end

    @(posedge clk_i);
    wr_en_i = 0;
  endtask

  task automatic fifo_read();

    @(posedge clk_i);

    if (!empty_o) begin

      rd_en_i = 1;

    end else begin

      $display("READ BLOCKED : FIFO EMPTY");

    end

    @(posedge clk_i);

    if (valid_o) model_read();

    rd_en_i = 0;

  endtask

  task automatic tb_error(input string msg);
    error_count++;
    $error("%s", msg);
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic reset_fifo();
    rst_ni  = 0;
    wr_en_i = 0;
    rd_en_i = 0;
    data_i  = 0;
    ref_fifo.delete();

    repeat (3) @(posedge clk_i);

    rst_ni = 1;
    @(posedge clk_i);

    assert (empty_o)
    else tb_error("FIFO NOT EMPTY AFTER RESET");

    assert (!full_o)
    else tb_error("FIFO FULL AFTER RESET");
  endtask

  //TC_001: Basic write/read sequence
  task automatic basic_test();


    error_before = error_count;
    $display(" BASIC TEST ");

    fifo_write(32'hAAAA);
    fifo_write(32'hBBBB);
    fifo_read();
    fifo_read();

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_002: Full flag assertion when FIFO is filled 
  task automatic full_test();
    integer i;


    error_before = error_count;
    $display(" FULL TEST ");
    for (i = 0; i < DEPTH; i++) fifo_write(i);

    @(posedge clk_i);
    assert (full_o)
    else tb_error("FIFO DID NOT BECOME FULL");

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask
  //TC_003: Empty flag assertion when FIFO is drained  
  task automatic empty_test();
    integer i;


    error_before = error_count;
    $display(" EMPTY TEST ");
    for (i = 0; i < DEPTH; i++) fifo_read();

    @(posedge clk_i);
    assert (empty_o)
    else tb_error("FIFO DID NOT BECOME EMPTY");

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_004: Simultaneous read/write operation  
  task automatic simultaneous_test();


    error_before = error_count;
    $display(" SIMULTANEOUS TEST ");

    fifo_write(32'd100);

    @(posedge clk_i);
    wr_en_i = 1;
    rd_en_i = 1;
    data_i  = 32'd200;
    model_write(32'd200);

    @(posedge clk_i);
    wr_en_i = 0;
    rd_en_i = 0;

    if (valid_o) model_read();
    fifo_read();

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_005: Randomized traffic stress test
  task automatic random_test();
    integer i;
    logic rand_wr;
    logic rand_rd;
    logic [DATA_WIDTH-1:0] rand_data;


    error_before = error_count;
    $display(" RANDOM TEST ");

    repeat (30) begin
      rand_wr   = $urandom_range(0, 1);
      rand_rd   = $urandom_range(0, 1);
      rand_data = $urandom;

      @(negedge clk_i);
      wr_en_i = rand_wr;
      rd_en_i = rand_rd;
      data_i  = rand_data;

      @(posedge clk_i);

      if (rand_rd && !empty_o) begin
        if (valid_o) model_read();
      end

      if (rand_wr && !full_o) begin
        model_write(rand_data);
      end

      @(negedge clk_i);
      wr_en_i = 1'b0;
      rd_en_i = 1'b0;
    end

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_006: Overflow handling when writing to a full FIFO
  task automatic overflow_test();
    integer i;
    logic [DATA_WIDTH-1:0] last_data;


    error_before = error_count;
    $display(" OVERFLOW TEST ");

    for (i = 0; i < DEPTH; i++) begin
      fifo_write(i);
    end

    @(posedge clk_i);
    assert (full_o)
    else tb_error("FIFO DID NOT BECOME FULL");

    last_data = 32'hDEADBEEF;

    @(posedge clk_i);
    wr_en_i = 1;
    data_i  = last_data;

    @(posedge clk_i);
    wr_en_i = 0;

    assert (full_o)
    else tb_error("FIFO LOST FULL CONDITION AFTER OVERFLOW ATTEMPT");

    for (i = 0; i < DEPTH; i++) begin
      fifo_read();
    end

    if (!empty_o) tb_error("FIFO NOT EMPTY AFTER DRAIN");

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_007: Data integrity across multiple write/read cycles
  task automatic data_integrity_test();
    int i;


    error_before = error_count;
    $display(" DATA INTEGRITY TEST ");
    for (i = 0; i < DEPTH; i++) fifo_write($urandom);
    for (i = 0; i < DEPTH; i++) fifo_read();

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_008: Underflow handling on an empty FIFO
  task automatic underflow_test();


    error_before = error_count;
    $display(" UNDERFLOW TEST ");

    reset_fifo();

    @(posedge clk_i);
    assert (empty_o)
    else tb_error("FIFO NOT EMPTY BEFORE UNDERFLOW TEST");

    rd_en_i = 1;

    @(posedge clk_i);
    rd_en_i = 0;

    @(posedge clk_i);
    assert (!valid_o)
    else tb_error("VALID ASSERTED DURING UNDERFLOW");

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_009: Reset during active operation
  task automatic reset_during_operation_test();


    error_before = error_count;
    $display(" RESET DURING OPERATION TEST ");

    fifo_write(32'hAAAA);
    fifo_write(32'hBBBB);
    fifo_write(32'hCCCC);

    assert (!empty_o)
    else tb_error("FIFO unexpectedly empty before reset");

    @(posedge clk_i);
    rst_ni  = 1'b0;
    wr_en_i = 1'b0;
    rd_en_i = 1'b0;
    data_i  = '0;
    ref_fifo.delete();

    repeat (3) @(posedge clk_i);

    rst_ni = 1'b1;
    @(posedge clk_i);

    assert (empty_o)
    else tb_error("FIFO not empty after reset during operation");

    assert (!full_o)
    else tb_error("FIFO full after reset during operation");

    assert (!valid_o)
    else tb_error("FIFO valid asserted after reset during operation");

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //TC_010: Simultaneous read/write on an empty FIFO
  task automatic simultaneous_empty_test();
    logic [DATA_WIDTH-1:0] write_data;


    error_before = error_count;
    $display(" SIMULTANEOUS READ/WRITE EMPTY TEST ");

    reset_fifo();

    write_data = 32'hAAAA_BBBB;

    @(posedge clk_i);

    wr_en_i = 1'b1;
    rd_en_i = 1'b1;
    data_i  = write_data;

    // DUT accepts only write because FIFO was empty
    model_write(write_data);

    @(posedge clk_i);

    wr_en_i = 1'b0;
    rd_en_i = 1'b0;

    // FIFO should now contain the written data
    fifo_read();

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask
  //TC_011: Simultaneous read/write on a full FIFO
  task automatic simultaneous_full_test();

    logic [DATA_WIDTH-1:0] write_data;


    error_before = error_count;
    $display(" SIMULTANEOUS READ/WRITE FULL TEST ");

    reset_fifo();

    for (int i = 0; i < DEPTH; i++) fifo_write(i);

    assert (full_o);

    write_data = 32'hDEAD_BEEF;

    @(posedge clk_i);

    wr_en_i = 1'b1;
    rd_en_i = 1'b1;
    data_i  = write_data;


    // update model because read happened
    if (ref_fifo.size() > 0) ref_fifo.pop_front();


    @(posedge clk_i);

    wr_en_i = 1'b0;
    rd_en_i = 1'b0;


    // check remaining data
    for (int i = 0; i < DEPTH - 1; i++) fifo_read();


    assert (empty_o)
    else tb_error("FIFO not empty");

    if (error_count == error_before) note_case(1'b1);
    else note_case(1'b0);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Assertions
  //////////////////////////////////////////////////////////////////////////////////////////////////

  property no_full_empty;
    @(posedge clk_i) !(full_o && empty_o);
  endproperty

  assert property (no_full_empty)
  else tb_error("FIFO FULL AND EMPTY BOTH HIGH");

  property reset_check;
    @(posedge clk_i) !rst_ni |-> empty_o;
  endproperty

  assert property (reset_check)
  else tb_error("FIFO NOT EMPTY AFTER RESET");
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // COVERAGE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  covergroup fifo_cov @(posedge clk_i);
    WRITE: coverpoint wr_en_i;
    READ: coverpoint rd_en_i;
    FULL: coverpoint full_o;
    EMPTY: coverpoint empty_o;
    WR_RD: cross wr_en_i, rd_en_i;
  endgroup

  covergroup fifo_level_cov;
    fifo_level: coverpoint ref_fifo.size() {
      bins empty = {0}; bins one = {1}; bins middle = {[2 : DEPTH - 1]}; bins full = {DEPTH};
    }
  endgroup

  covergroup fifo_overflow_cov @(posedge clk_i);
    WRITE_WHEN_FULL: coverpoint (wr_en_i && full_o) {bins overflow_attempt = {1};}
  endgroup

  covergroup fifo_underflow_cov @(posedge clk_i);
    READ_WHEN_EMPTY: coverpoint (rd_en_i && empty_o) {bins underflow_attempt = {1};}
  endgroup

  fifo_cov fifo_cov_inst = new();
  fifo_level_cov fifo_level_cov_inst = new();
  fifo_overflow_cov fifo_overflow_cov_inst = new();
  fifo_underflow_cov fifo_underflow_cov_inst = new();

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // COVERAGE REPORT
  ////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic report_coverage();

    real cov;

    cov = fifo_cov_inst.get_coverage();

    $display("\033[2;36m////////////////////////////////////////\033[0m");
    $display("\033[2;36mFIFO Functional Coverage = %0.2f %%\033[0m", cov);
    $display("\033[2;36m////////////////////////////////////////\033[0m");

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Clock Generation
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    clk_i = 0;
    forever #5 clk_i = ~clk_i;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //main initial
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    reset_fifo();

    case (test_name)

      "basic": begin
        basic_test();
      end

      "full": begin
        full_test();
      end

      "empty": begin
        empty_test();
      end

      "overflow": begin
        overflow_test();
      end

      "underflow": begin
        underflow_test();
      end

      "simultaneous": begin
        simultaneous_test();
      end

      "integrity": begin
        data_integrity_test();
      end

      "random": begin
        random_test();
      end

      "reset": begin
        reset_during_operation_test();
      end

      "sim_empty": begin
        simultaneous_empty_test();
      end

      "sim_full": begin
        simultaneous_full_test();
      end

      "all": begin
        basic_test();
        full_test();
        empty_test();
        overflow_test();
        underflow_test();
        simultaneous_test();
        data_integrity_test();
        random_test();
        reset_during_operation_test();
        simultaneous_empty_test();
        simultaneous_full_test();
      end

      default: begin
        $error("UNKNOWN TEST NAME: %s", test_name);
        $display("Available tests:");
        $display("basic");
        $display("full");
        $display("empty");
        $display("overflow");
        $display("underflow");
        $display("simultaneous");
        $display("integrity");
        $display("random");
        $display("reset");
        $display("sim_empty");
        $display("sim_full");
        $display("all");
      end

    endcase


    report_coverage();

    $finish;

  end
endmodule
