/*

| TEST CASE | DATE       | AUTHOR         | DESCRIPTION                                             |
|-----------|------------|----------------|---------------------------------------------------------|  
| TC_001    | 2026-08-06 | Shuparna Haque | Minimum bounds                                          |
| TC_002    | 2026-08-06 | Shuparna Haque | Mid bounds                                              |
| TC_003    | 2026-08-06 | Shuparna Haque | Maximum bounds                                          |
| TC_004    | 2026-08-06 | Shuparna Haque | Out of bound                                            |
| TC_005    | 2026-08-06 | Shuparna Haque | Random                                                  |
| TC_ALL    | 2026-08-06 | Shuparna Haque | All                                                     |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-07-30 | Shuparna Haque  | Initial version                                        |
| 1.0      | 2026-08-02 | Shuparna Haque  | Stable release                                         |
| 1.1      | 2026-08-06 | Foez Ahmed      | Ratified                                               |

Author : Shuparna Haque (sheikhshuparna3108@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_address_decoder_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = 14;  // Width of the address bus
  localparam int SLAVE_ID_WIDTH = 2;  // Width of the slave identifier
  localparam int NUM_RULES = 25;  // Number of address ranges to decode

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [    ADDR_WIDTH-1:0] addr_i;
  logic [    ADDR_WIDTH-1:0] min_addr_i    [NUM_RULES];
  logic [    ADDR_WIDTH-1:0] max_addr_i    [NUM_RULES];
  logic [SLAVE_ID_WIDTH-1:0] slave_id_i    [NUM_RULES];
  logic [SLAVE_ID_WIDTH-1:0] slave_index_o;
  logic                      addr_found_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_address_decoder #(
      .ADDR_WIDTH    (ADDR_WIDTH),
      .NUM_RULES     (NUM_RULES),
      .SLAVE_ID_WIDTH(SLAVE_ID_WIDTH)
  ) u_dut (
      .addr_i       (addr_i),
      .min_addr_i   (min_addr_i),
      .max_addr_i   (max_addr_i),
      .slave_id_i   (slave_id_i),
      .slave_index_o(slave_index_o),
      .addr_found_o (addr_found_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic set_rule_table();
    for (int i = 0; i < NUM_RULES; i++) begin
      int min_addr;
      int max_addr;
      int slave_id;

      void'(std::randomize(
          min_addr, max_addr, slave_id
      ) with {
        (min_addr + 2) < max_addr;
        min_addr >= 0;
        max_addr < 2 ** ADDR_WIDTH;
        slave_id < 2 ** SLAVE_ID_WIDTH;
      });

      min_addr_i[i] = min_addr;
      max_addr_i[i] = max_addr;
      slave_id_i[i] = slave_id;
    end
    foreach (min_addr_i[i]) begin
      $display("Rule %02d: min_addr = 0x%03h, max_addr = 0x%03h, slave_id = %0d", i, min_addr_i[i],
               max_addr_i[i], slave_id_i[i]);
    end
  endtask

  function automatic bit is_in_range(input logic [ADDR_WIDTH-1:0] addr);
    foreach (min_addr_i[i]) begin
      if (addr >= min_addr_i[i] && addr < max_addr_i[i]) begin
        return 1'b1;
      end
    end
    return 0;
  endfunction

  task automatic exp_gen(input logic [ADDR_WIDTH-1:0] addr_i,
                         output logic [SLAVE_ID_WIDTH-1:0] expected_index,
                         output logic expected_found);
    expected_found = '0;
    foreach (min_addr_i[i]) begin
      if (addr_i >= min_addr_i[i] && addr_i < max_addr_i[i]) begin
        expected_found = 1'b1;
        expected_index = slave_id_i[i];
      end
    end
  endtask

  task automatic check_address(input logic [ADDR_WIDTH-1:0] addr);

    logic [SLAVE_ID_WIDTH-1:0] expected_index;
    logic expected_found;
    bit OK;

    OK = 1;

    addr_i <= addr;
    #1;

    exp_gen(addr_i, expected_index, expected_found);

    if (addr_found_o !== expected_found) begin
      OK = 0;
      $display(
          "\033[1;31mError: addr_found_o mismatch for addr 0x%03h. Expected: %0d, Got: %0d\033[0m",
          addr_i, expected_found, addr_found_o);
    end
    if (expected_found && (slave_index_o !== expected_index)) begin
      OK = 0;
      $display(
          "\033[1;31mError: slave_index_o mismatch for addr 0x%03h. Expected: %0d, Got: %0d\033[0m",
          addr_i, expected_index, slave_index_o);
    end
    note_case(OK);

  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial
    logic [ADDR_WIDTH-1:0] out_of_bound_addr[$];

    do begin
      out_of_bound_addr.delete();
      $display("\033[7;33mADDRESS ITERATION\033[0m");
      set_rule_table();
      for (int i = 0; i < 2 ** ADDR_WIDTH; i++) begin
        if (!is_in_range(i)) begin
          out_of_bound_addr.push_back(i);
        end
      end
      $display("Total out-of-bound addresses: %0d", out_of_bound_addr.size());
    end while (out_of_bound_addr.size() < 300);

    case (test_name)

      "TC_001": begin
        foreach (min_addr_i[i]) begin
          check_address(min_addr_i[i]);
        end
      end

      "TC_002": begin
        foreach (min_addr_i[i]) begin
          check_address($urandom_range(min_addr_i[i] + 1, max_addr_i[i] - 2));
        end
      end

      "TC_003": begin
        foreach (max_addr_i[i]) begin
          check_address(max_addr_i[i] - 1);
        end
      end

      "TC_004": begin
        foreach (out_of_bound_addr[i]) begin
          check_address(out_of_bound_addr[i]);
        end
      end

      "TC_005":
      repeat (test_count) begin
        check_address($urandom);
      end

      "TC_ALL": begin
        test_count = 1000;
        foreach (min_addr_i[i]) begin
          check_address(min_addr_i[i]);
          check_address($urandom_range(min_addr_i[i] + 1, max_addr_i[i] - 2));
          check_address(max_addr_i[i] - 1);
        end
        foreach (out_of_bound_addr[i]) begin
          check_address(out_of_bound_addr[i]);
        end
        repeat (test_count) begin
          check_address($urandom);
        end
      end

      default: begin
        $display("\033[1;31mError: Unknown test case '%s'\033[0m", test_name);
      end

    endcase

    $finish;

  end

endmodule
