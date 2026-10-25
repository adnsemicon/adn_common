/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                            |
|-----------|------------|-----------------|--------------------------------------------------------|  
| TC_001    | 2026-08-19 | Shuparna Haque  | Minimum, mid, and maximum address bound                |
| TC_002    | 2026-08-19 | Shuparna Haque  | All addresses, valid asserted                          |
| TC_003    | 2026-08-19 | Shuparna Haque  | Valid gating - all addresses, valid deasserted         |
| TC_004    | 2026-08-19 | Shuparna Haque  | Toggle valid with address held constant                |
| TC_005    | 2026-08-19 | Shuparna Haque  | Address sweep with valid held asserted                 |
| TC_006    | 2026-08-19 | Shuparna Haque  | Random address and valid                               |
| TC_ALL    | 2026-08-19 | Shuparna Haque  | All of the above                                       |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                      

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0      | 2026-08-19 | Shuparna Haque  | Initial release                                         |

Author : Shuparna Haque (sheikhshuparna3108@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_decoder_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH = 4;  // Width of the input address bus
  localparam int DATA_WIDTH = (2 ** ADDR_WIDTH);  // Width of the decoded output bus

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [ADDR_WIDTH-1:0] addr_i;  // Binary address input
  logic                  addr_valid_i;  // Validity signal for the input ad

  logic [DATA_WIDTH-1:0] d_o;  // One-hot decoded output
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLASSES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_common_decoder #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .addr_i(addr_i),
      .addr_valid_i(addr_valid_i),
      .d_o(d_o)
  );
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic check_decoder(input logic [ADDR_WIDTH-1 : 0] addr, input logic valid);
    logic [DATA_WIDTH-1 : 0] exp_d_o;
    bit ok;

    ok = 1'b1;

    addr_i <= addr;
    addr_valid_i <= valid;
    #1;

    exp_d_o = '0;
    if (valid) begin
      exp_d_o[addr] = 1'b1;

      if (d_o !== exp_d_o) begin
        ok = 1'b0;
        $display("Error : d_o mismatch for addr %b, valid %b, Expected : %b, Got : %b", addr,
                 valid, exp_d_o, d_o);
      end else begin
        ok = 1'b1;
        $display("Pass : d_o match for addr %b, valid %b, Expected : %b, Got : %b", addr, valid,
                 exp_d_o, d_o);
      end
    end else begin
      $display("Address Validity is not given for addr %b.", addr);
    end
    note_case(ok);
  endtask
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial
    case (test_name)
      "TC_001": begin
        $display("=======================Minimum Bound=======================");
        check_decoder(4'b0000, 1'b1);
        $display("=======================Mid Bound=======================");
        check_decoder(DATA_WIDTH / 2, 1'b1);
        $display("=======================Maximum Bound=======================");
        check_decoder(DATA_WIDTH - 1, 1'b1);
      end
      "TC_002": begin
        $display("======================Full Address Sweep=====================");
        for (int i = 0; i < DATA_WIDTH; i++) begin
          check_decoder(i[ADDR_WIDTH-1:0], 1'b1);
        end
      end
      "TC_003": begin
        $display("=======================Valid Gating=======================");
        for (int i = 0; i < DATA_WIDTH; i++) begin
          check_decoder(i[ADDR_WIDTH-1:0], 1'b0);
        end
      end
      "TC_004": begin
        $display("=======================Toggle Valid=======================");
        check_decoder(4'b0000, 1'b1);
        check_decoder(4'b0000, 1'b0);
        check_decoder(4'b0000, 1'b1);
      end
      "TC_005": begin
        $display("=======================Addr Sweep, Valid Held=======================");
        for (int i = 0; i < DATA_WIDTH; i++) begin
          check_decoder(i[ADDR_WIDTH-1:0], 1'b1);
        end
      end
      "TC_006": begin
        $display("===========================Random============================");
        check_decoder($urandom_range(0, DATA_WIDTH - 1), $urandom_range(0, 1));
      end
      "TC_ALL": begin
        check_decoder(4'b0000, 1'b1);
        check_decoder(DATA_WIDTH / 2, 1'b1);
        check_decoder(DATA_WIDTH - 1, 1'b1);
        for (int i = 0; i < DATA_WIDTH; i++) begin
          check_decoder(i[ADDR_WIDTH-1:0], 1'b1);
        end
        for (int i = 0; i < DATA_WIDTH; i++) begin
          check_decoder(i[ADDR_WIDTH-1:0], 1'b0);
        end
        check_decoder(4'b0000, 1'b1);
        check_decoder(4'b0000, 1'b0);
        check_decoder(4'b0000, 1'b1);
        for (int i = 0; i < DATA_WIDTH; i++) begin
          check_decoder(i[ADDR_WIDTH-1:0], 1'b1);
        end
        check_decoder($urandom_range(0, DATA_WIDTH - 1), $urandom_range(0, 1));
      end
    endcase


    $finish;

  end

endmodule
