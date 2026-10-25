/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|
| TC_001    | 2026-08-19 | Adnan Sami Anirban | Simple Read Write                                  |
| TC_001    | 2026-08-19 | Adnan Sami Anirban | Multiple random write and read                     |
| TC_001    | 2026-08-19 | Adnan Sami Anirban | Simultanious read and write                        |
| TC_002    | 2026-08-19 | Adnan Sami Anirban | Write enable test                                  |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-18 | Adnan Sami Anirban | Initial version                                     |
| 1.0      | 2026-08-18 | Adnan Sami Anirban | Stable release                                      |

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
    localparam CLOCK_PERIOD   = 10;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
    logic                   clk_i    ;
    logic                   wr_en_i  ;
    logic [ADDR_WIDTH-1:0]  wr_addr_i;
    logic [DATA_WIDTH-1:0]  wr_data_i;
    logic [ADDR_WIDTH-1:0]  rd_addr_i;
    logic [DATA_WIDTH-1:0]  rd_data_o;

    // Model Memory
    logic [DATA_WIDTH-1:0] model_mem [int unsigned];
    logic [DATA_WIDTH-1:0] rdata;
    logic [ADDR_WIDTH:0] waddr_en[$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin 
    clk_i = 0;
  end
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

adn_common_dual_port_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
)dut(
    .clk_i    (clk_i    ),
    .wr_en_i  (wr_en_i  ),
    .wr_addr_i(wr_addr_i),
    .wr_data_i(wr_data_i),
    .rd_addr_i(rd_addr_i),
    .rd_data_o(rd_data_o)
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
task automatic start_clk;
  forever begin 
    #(CLOCK_PERIOD / 2);
    clk_i <= 1;
    #(CLOCK_PERIOD / 2);
    clk_i <= 0;
  end
endtask

task automatic write(input logic [DATA_WIDTH - 1:0] wdata, input logic [ADDR_WIDTH - 1:0] waddr, input logic wen = 'b1);
  @(posedge clk_i);
  wr_addr_i        <= waddr;
  wr_data_i        <= wdata;
  wr_en_i          <= wen;
  #1step;
  if (wen) model_mem[waddr] =  wdata;
endtask

task automatic read(output logic [DATA_WIDTH - 1:0] rdata, input logic [ADDR_WIDTH - 1:0] raddr);
  @(posedge clk_i);
  rd_addr_i        <= raddr;
  #1step;
  rdata            = rd_data_o;

endtask

task automatic check(input logic [ADDR_WIDTH - 1:0] raddr, input logic [DATA_WIDTH - 1:0] rdata);
  if(rdata === model_mem[raddr]) begin
    $display("[PASS]: At RADDR: %h, EXPECTED: %h, GOT: %h", raddr, model_mem[raddr], rdata);
    note_case(1);
  end else begin 
    $error("[FAIL]: At RADDR: %h, EXPECTED: %h, but GOT: %h", raddr, model_mem[raddr], rdata);
    note_case(0);
  end
endtask

task automatic simple_wr_rd;
    write('h3234, 'h10, '1);
    read (rdata, 'h10);
    check('h10, rdata);
endtask

task automatic multiple_wr();
    logic [ADDR_WIDTH - 1:0] rand_waddr;
    logic [DATA_WIDTH - 1:0] rand_wdata;
    logic                    rand_wen  ;
    for (int i = 0; i<20; i++) begin
      rand_waddr = $urandom_range(1,1000);
      rand_wdata = $urandom_range(1,200);
      rand_wen   = $urandom_range(0,1);
      #1step;
      write(rand_wdata, rand_waddr, rand_wen);
      waddr_en.push_back({rand_wen, rand_waddr});
    end
endtask

task automatic multiple_rd();
    logic [ADDR_WIDTH:0] wr_en_q;
    for (int i = 0; i < 20; i++) begin
      wr_en_q = waddr_en.pop_front();

      if(wr_en_q[ADDR_WIDTH]) begin
        read(rdata, wr_en_q[ADDR_WIDTH -1:0]);
        check(wr_en_q[ADDR_WIDTH -1:0], rdata);   
      end
    end

endtask

task automatic multiple_wr_rd();
    multiple_wr();
    multiple_rd();
endtask

// at a time write and read;
task automatic simul_wr_and_rd();
    write('hBEEF, 'hFE, 1);
    fork
      write('hDEAD, 'hAD, 1);
      read (rdata, 'hFE);
    join
    check('hFE, rdata);
    read(rdata, 'hAD);
    check('hAD, rdata);
endtask


task automatic wen_test();
      write('hEAAD, 'hAD, 0);
      read (rdata, 'hAD);
      if(rdata !== 'hEAAD) begin 
        $display("[PASS]: AS wen = 0, no write happen");
        note_case(1);
      end
      else begin $error("[FAIL]: wen = 0, but write happen"); note_case(0); end
      write('hEAAD, 'hAD, 1);
      read (rdata, 'hAD);
      if(rdata === 'hEAAD) begin $display("[PASS]: AS wen = 1, write happen"); note_case(1); end
      else begin $error("[FAIL]: AS wen = 0, no write happen"); note_case(0);end
endtask








  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    rdata = 0;
    fork
      start_clk();   
    join_none

case(test_name)
  "TC_ALL": begin
    simple_wr_rd();
    multiple_wr_rd();
    simul_wr_and_rd();
    wen_test();
  end
  "TC_001": simple_wr_rd();
  "TC_002": multiple_wr_rd();
  "TC_003": simul_wr_and_rd();
  "TC_004": wen_test();

endcase

    repeat(5) @(posedge clk_i);
    $finish;

  end
endmodule
