/*

| TEST CASE | DATE       | AUTHOR     | DESCRIPTION                                                          |
|-----------|------------|------------|----------------------------------------------------------------------|
| TC_001    | 2026-11-01 | Adnan Sami | Simple write and read verification with distinct data patterns       |
| TC_002    | 2026-11-01 | Adnan Sami | Write enable gating verification (write blocked when disabled)       |
| TC_003    | 2026-11-01 | Adnan Sami | Simultaneous read and write to different memory addresses            |
| TC_004    | 2026-11-01 | Adnan Sami | Same-cycle read and write to the same memory address                 |
| TC_005    | 2026-11-01 | Adnan Sami | Boundary address space traversal (first, last, and partition limits) |
| TC_006    | 2026-11-01 | Adnan Sami | Randomized multiple write and read operations vs shadow model        |
| TC_ALL    | 2026-11-01 | Adnan Sami | Run all test cases in sequence                                       |

| REVISION | DATE       | AUTHOR     | DESCRIPTION                                            |
|----------|------------|------------|--------------------------------------------------------|
| 0.1      | 2026-08-18 | Adnan Sami | Initial version                                        |
| 1.0      | 2026-08-18 | Adnan Sami | Stable release                                         |
| 1.1      | 2026-11-01 | Adnan Sami | Recreated following template with functional coverage  |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_dual_port_ram_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int DATA_WIDTH = 32;
  localparam int ADDR_WIDTH = 8;
  localparam int DEPTH = 1 << ADDR_WIDTH;
  localparam time CLK_PERIOD = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                  clk_i = 1'b0;
  logic                  wr_en_i;
  logic [ADDR_WIDTH-1:0] wr_addr_i;
  logic [DATA_WIDTH-1:0] wr_data_i;
  logic [ADDR_WIDTH-1:0] rd_addr_i;
  logic [DATA_WIDTH-1:0] rd_data_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Shadow reference memory model
  logic [DATA_WIDTH-1:0] shadow_mem   [DEPTH];
  bit                    mem_written  [DEPTH];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // COVERAGE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  covergroup ram_wr_cov @(posedge clk_i);
    option.per_instance = 1;

    cp_wr_en: coverpoint wr_en_i {bins disabled = {1'b0}; bins enabled = {1'b1};}

    cp_wr_addr: coverpoint wr_addr_i {
      bins zero = {0};
      bins max = {DEPTH - 1};
      bins low_range = {[1 : (DEPTH / 2) - 1]};
      bins high_range = {[(DEPTH / 2) : DEPTH - 2]};
    }

    cp_wr_data: coverpoint wr_data_i {
      bins zeros = {'0};
      bins ones = {'1};
      bins alt_aa = {32'hAAAAAAAA};
      bins alt_55 = {32'h55555555};
      bins others = default;
    }

    cross_wr_en_addr: cross cp_wr_en, cp_wr_addr;
  endgroup

  covergroup ram_rd_cov @(posedge clk_i);
    option.per_instance = 1;

    cp_rd_addr: coverpoint rd_addr_i {
      bins zero = {0};
      bins max = {DEPTH - 1};
      bins low_range = {[1 : (DEPTH / 2) - 1]};
      bins high_range = {[(DEPTH / 2) : DEPTH - 2]};
    }

    cp_rd_data: coverpoint rd_data_o {
      bins zeros = {'0};
      bins ones = {'1};
      bins alt_aa = {32'hAAAAAAAA};
      bins alt_55 = {32'h55555555};
      bins others = default;
    }
  endgroup

  covergroup ram_simul_cov @(posedge clk_i);
    option.per_instance = 1;

    cp_wr_active: coverpoint wr_en_i {bins inactive = {1'b0}; bins active = {1'b1};}

    cp_same_addr: coverpoint (wr_addr_i == rd_addr_i) {
      bins diff_addr = {1'b0}; bins same_addr = {1'b1};
    }

    cross_simul: cross cp_wr_active, cp_same_addr;
  endgroup

  ram_wr_cov    wr_cov_inst    = new();
  ram_rd_cov    rd_cov_inst    = new();
  ram_simul_cov simul_cov_inst = new();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_dual_port_ram #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (
      .clk_i    (clk_i),
      .wr_en_i  (wr_en_i),
      .wr_addr_i(wr_addr_i),
      .wr_data_i(wr_data_i),
      .rd_addr_i(rd_addr_i),
      .rd_data_o(rd_data_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Free-running clock generator
  initial forever #(CLK_PERIOD / 2.0) clk_i = ~clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Drives write port setup cleanly on negedge so it is stable at posedge
  task automatic write_mem(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                           input logic en = 1'b1);
    @(negedge clk_i);
    wr_addr_i = addr;
    wr_data_i = data;
    wr_en_i   = en;

    @(posedge clk_i);
    if (en) begin
      shadow_mem[addr]  = data;
      mem_written[addr] = 1'b1;
    end

    @(negedge clk_i);
    wr_en_i = 1'b0;
  endtask

  // Drives read port setup on negedge and captures output after settling
  task automatic read_mem(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data);
    @(negedge clk_i);
    rd_addr_i = addr;
    #1ns;
    data = rd_data_o;
  endtask

  // Verifies read data matches expected value
  task automatic check_read(input logic [ADDR_WIDTH-1:0] addr,
                            input logic [DATA_WIDTH-1:0] expected, input string tag);
    logic [DATA_WIDTH-1:0] got;
    read_mem(addr, got);
    if (got === expected) begin
      note_case(1'b1);
      if (debug) begin
        $display("[PASS] %s: addr=0x%0h exp=0x%08h got=0x%08h [%0t]", tag, addr, expected, got,
                 $realtime);
      end
    end else begin
      $display("[FAIL] %s: addr=0x%0h exp=0x%08h got=0x%08h [%0t]", tag, addr, expected, got,
               $realtime);
      note_case(1'b0);
    end
  endtask

  // Initializes all testbench interface signals
  task automatic init_tb();
    wr_en_i   = 1'b0;
    wr_addr_i = '0;
    wr_data_i = '0;
    rd_addr_i = '0;
    repeat (2) @(posedge clk_i);
  endtask

  // TC_001: Simple write and read verification with pattern variations
  task automatic tc_simple_wr_rd();
    init_tb();
    write_mem(8'h10, 32'h00000000);
    check_read(8'h10, 32'h00000000, "TC_001 Zeros");

    write_mem(8'h11, 32'hFFFFFFFF);
    check_read(8'h11, 32'hFFFFFFFF, "TC_001 Ones");

    write_mem(8'h12, 32'hAAAAAAAA);
    check_read(8'h12, 32'hAAAAAAAA, "TC_001 AltAA");

    write_mem(8'h13, 32'h55555555);
    check_read(8'h13, 32'h55555555, "TC_001 Alt55");

    write_mem(8'h14, 32'h12345678);
    check_read(8'h14, 32'h12345678, "TC_001 Pattern");
  endtask

  // TC_002: Write enable gating verification (write blocked when disabled)
  task automatic tc_wen_gating();
    logic [DATA_WIDTH-1:0] initial_val;
    logic [DATA_WIDTH-1:0] readback;
    init_tb();

    // First write a known initial value
    initial_val = 32'hCAFEBABE;
    write_mem(8'h42, initial_val, 1'b1);
    check_read(8'h42, initial_val, "TC_002 Initial write");

    // Attempt to write new data while wr_en_i is disabled (0)
    write_mem(8'h42, 32'hDEADBEEF, 1'b0);
    read_mem(8'h42, readback);
    if (readback === initial_val) begin
      $display("[PASS] TC_002: write blocked when wr_en=0 [%0t]", $realtime);
      note_case(1'b1);
    end else begin
      $display("[FAIL] TC_002: memory changed when wr_en=0! got=0x%08h [%0t]", readback, $realtime);
      note_case(1'b0);
    end

    // Now write with wr_en_i enabled (1)
    write_mem(8'h42, 32'hDEADBEEF, 1'b1);
    check_read(8'h42, 32'hDEADBEEF, "TC_002 Overwrite when enabled");
  endtask

  // TC_003: Simultaneous read and write to different memory addresses
  task automatic tc_simul_diff_addr();
    logic [DATA_WIDTH-1:0] got_rd;
    init_tb();

    write_mem(8'hA0, 32'h11112222, 1'b1);
    write_mem(8'hB0, 32'h33334444, 1'b1);

    // Concurrently read from A0 while writing new data to B0
    @(negedge clk_i);
    wr_addr_i = 8'hB0;
    wr_data_i = 32'h55556666;
    wr_en_i   = 1'b1;
    rd_addr_i = 8'hA0;

    @(posedge clk_i);
    shadow_mem[8'hB0]  = 32'h55556666;
    mem_written[8'hB0] = 1'b1;
    #1ns;
    got_rd = rd_data_o;

    @(negedge clk_i);
    wr_en_i = 1'b0;

    // Verify read from A0 was stable and unaffected
    if (got_rd === 32'h11112222) begin
      $display("[PASS] TC_003: simultaneous read from diff addr unaffected [%0t]", $realtime);
      note_case(1'b1);
    end else begin
      $display("[FAIL] TC_003: simultaneous read corrupted: got=0x%08h [%0t]", got_rd, $realtime);
      note_case(1'b0);
    end

    // Verify B0 received the newly written value
    check_read(8'hB0, 32'h55556666, "TC_003 Concurrent write result");
  endtask

  // TC_004: Same-cycle read and write to the same memory address
  task automatic tc_same_addr_rw();
    logic [DATA_WIDTH-1:0] got_rd;
    init_tb();

    write_mem(8'h77, 32'hAAAA0000, 1'b1);

    // Apply write and read to the same address in the same clock cycle
    @(negedge clk_i);
    wr_addr_i = 8'h77;
    wr_data_i = 32'hBBBB1111;
    wr_en_i   = 1'b1;
    rd_addr_i = 8'h77;

    @(posedge clk_i);
    shadow_mem[8'h77]  = 32'hBBBB1111;
    mem_written[8'h77] = 1'b1;
    #1ns;
    got_rd = rd_data_o;

    @(negedge clk_i);
    wr_en_i = 1'b0;

    // Memory output reflects written data
    if (got_rd === 32'hBBBB1111) begin
      $display("[PASS] TC_004: same address read reflects write on posedge [%0t]", $realtime);
      note_case(1'b1);
    end else begin
      $display("[FAIL] TC_004: same address read mismatch: got=0x%08h [%0t]", got_rd, $realtime);
      note_case(1'b0);
    end

    check_read(8'h77, 32'hBBBB1111, "TC_004 Readback verification");
  endtask

  // TC_005: Boundary address space traversal (first, last, and partition limits)
  task automatic tc_boundary_addresses();
    init_tb();

    // Boundary: Address 0
    write_mem('0, 32'hA0A0A0A0, 1'b1);
    check_read('0, 32'hA0A0A0A0, "TC_005 Address 0");

    // Boundary: Address 1 (low range)
    write_mem(8'd1, 32'hA1A1A1A1, 1'b1);
    check_read(8'd1, 32'hA1A1A1A1, "TC_005 Address 1");

    // Boundary: Midpoint (high range boundary)
    write_mem(8'd128, 32'hA2A2A2A2, 1'b1);
    check_read(8'd128, 32'hA2A2A2A2, "TC_005 Address 128");

    // Boundary: Address DEPTH - 1 (maximum address)
    write_mem(DEPTH - 1, 32'hA3A3A3A3, 1'b1);
    check_read(DEPTH - 1, 32'hA3A3A3A3, "TC_005 Max Address");
  endtask

  // TC_006: Randomized multiple write and read operations vs shadow model
  task automatic tc_randomized_stress();
    localparam int NUM_OPS = 100;
    logic [ADDR_WIDTH-1:0] written_addresses[$];
    init_tb();

    for (int i = 0; i < NUM_OPS; i++) begin
      automatic logic [ADDR_WIDTH-1:0] r_addr = $urandom;
      automatic logic [DATA_WIDTH-1:0] r_data = $urandom;
      automatic logic                  r_en = ($urandom_range(0, 9) != 0);  // 90% writes

      write_mem(r_addr, r_data, r_en);
      if (r_en) written_addresses.push_back(r_addr);

      // Random interleaved read
      if (written_addresses.size() > 0) begin
        automatic int idx = $urandom_range(0, written_addresses.size() - 1);
        automatic logic [ADDR_WIDTH-1:0] check_a = written_addresses[idx];
        check_read(check_a, shadow_mem[check_a], "TC_006 Random Read");
      end
    end
  endtask

  // Runs all test cases in sequence
  task automatic run_all();
    tc_simple_wr_rd();
    tc_wen_gating();
    tc_simul_diff_addr();
    tc_same_addr_rw();
    tc_boundary_addresses();
    tc_randomized_stress();
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial
    automatic int iterations;
    iterations = (test_count > 0) ? test_count : 1;

    for (int iter = 0; iter < iterations; iter++) begin
      case (test_name)
        "TC_001":                   tc_simple_wr_rd();
        "TC_002":                   tc_wen_gating();
        "TC_003":                   tc_simul_diff_addr();
        "TC_004":                   tc_same_addr_rw();
        "TC_005":                   tc_boundary_addresses();
        "TC_006":                   tc_randomized_stress();
        "TC_ALL", "all", "default": run_all();
        default: begin
          $display("Unrecognized test name '%s', running TC_ALL", test_name);
          run_all();
        end
      endcase
    end

    repeat (5) @(posedge clk_i);
    $finish;
  end

endmodule
