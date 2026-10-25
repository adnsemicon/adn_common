/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|  
| TC_001    | 2026-09-08 | Foez Ahmed      | Test case description goes here                       |
| TC_002    | 2026-09-08 | Foez Ahmed      | Test case description goes here                       |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-08 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-09-08 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_hs_combiner_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [3:0] valid_i;
  logic [3:0] ready_o;
  logic [3:0] valid_o;
  logic [3:0] ready_i;

  covergroup cov_gr with function sample ();
    valid_i_cp: coverpoint valid_i;
    ready_i_cp: coverpoint ready_i;
    cross_cp: cross valid_i_cp, ready_i_cp;
  endgroup

  cov_gr cg = new();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_hs_combiner #(
      .NUM_TX(4),
      .NUM_RX(4)
  ) u_dut (
      .*
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial

    for (int i = 0; i < 256; i++) begin
      bit res;
      {valid_i, ready_i} = i;
      #1step;
      cg.sample();
      res = &valid_i & &ready_i;
      foreach (valid_o[i]) note_case(valid_o[i] == res);
      foreach (ready_o[i]) note_case(ready_o[i] == res);
    end

    $finish;

  end

endmodule
