/*

### Test Cases

| TEST CASE | DATE       | AUTHOR                       | DESCRIPTION                                              |
|-----------|------------|------------------------------|----------------------------------------------------------|
| TC_001    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify asynchronous reset functionality                  |
| TC_002    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify single input handshake increments counter          |
| TC_003    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify multiple input handshakes increment counter       |
| TC_004    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify single output handshake decrements counter        |
| TC_005    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify multiple output handshakes decrement counter      |
| TC_006    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify full counter condition and input backpressure     |
| TC_007    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify empty counter condition and output valid signal   |
| TC_008    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify overflow protection at maximum depth              |
| TC_009    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify underflow protection at zero occupancy            |
| TC_010    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify simultaneous input and output handshakes          |
| TC_011    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify empty and full boundary conditions                |
| TC_012    | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Verify random handshake sequences using reference model  |

### Revision History

| REVISION | DATE       | AUTHOR                       | DESCRIPTION                                      |
|----------|------------|------------------------------|--------------------------------------------------|
| 0.1      | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Initial testbench version                        |
| 1.0      | 2026-08-06 | MD Sakhawat Hossain Sabbir   | Stable release with complete test coverage       |

Author : MD Sakhawat Hossain Sabbir (sabbirone939@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_common_hs_counter_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int DEPTH = 8;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic clk_i;
  logic arst_ni;

  logic data_in_valid_i;
  logic data_in_ready_o;

  logic data_out_valid_o;
  logic data_out_ready_i;

  logic [$clog2(DEPTH+1)-1:0] count_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  int error_count;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLASSES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////
  // CLOCK
  ////////////////////////////////////////////////////////////////
  initial clk_i = 0;
  always #5 clk_i = ~clk_i;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_common_hs_counter #(
      .DEPTH(DEPTH)
  ) dut (
      .clk_i(clk_i),
      .arst_ni(arst_ni),

      .data_in_valid_i(data_in_valid_i),
      .data_in_ready_o(data_in_ready_o),

      .data_out_valid_o(data_out_valid_o),
      .data_out_ready_i(data_out_ready_i),

      .count_o(count_o)
  );
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Reset Task

  task automatic reset_dut();
  begin
    data_in_valid_i  = 1'b0;
    data_out_ready_i = 1'b0;

    arst_ni = 1'b0;
    repeat(2) @(posedge clk_i);
    arst_ni = 1'b1;
    @(posedge clk_i);

  end
  endtask


// Push Task
  task automatic push();
  begin

    @(negedge clk_i);
    data_in_valid_i = 1'b1;

    @(negedge clk_i);
    data_in_valid_i = 1'b0;

  end
  endtask

// Pop Task
task automatic pop();
begin

    @(negedge clk_i);
    data_out_ready_i = 1'b1;

    @(negedge clk_i);
    data_out_ready_i = 1'b0;

end
endtask

// Push + Pop Same Cycle
task automatic push_pop();
begin

    @(negedge clk_i);
    data_in_valid_i  = 1'b1;
    data_out_ready_i = 1'b1;

    @(negedge clk_i);
    data_in_valid_i  = 1'b0;
    data_out_ready_i = 1'b0;

end
endtask

// Count Checker
task automatic check_count(input int expected);

begin
    if(count_o !== expected) begin
        $error("COUNT ERROR : Expected=%0d Got=%0d",
                expected,count_o);
        error_count++;
    end
    else begin
        $display("COUNT OK : Expected=%0d Got=%0d",
                 expected,count_o);
    end

end

endtask


//Tests:
// Reset Test
task automatic reset_test();

begin

    error_count = 0;
    reset_dut();
    if(count_o !== 0) begin
        $error("Reset failed : count not zero");
        error_count++;
    end
  
    else begin
        $display("Reset test passed : %0d", count_o);
    end
    note_case(error_count == 0);
end

endtask

//Single Push Test
task automatic single_push_test();

begin

    error_count = 0;
    reset_dut();
    push();

    check_count(1);

    note_case(error_count == 0);
end

endtask

//Multiple Push Test
task automatic multiple_push_test();

begin
    error_count = 0;
    reset_dut();

    repeat(5)
        push();

    check_count(5);
    note_case(error_count == 0);
end

endtask

//Single Pop Test
task automatic single_pop_test();

begin
    error_count = 0;
    reset_dut();

    push();

    pop();

    check_count(0);
    note_case(error_count == 0);

end

endtask

// Multiple Pop Test
task automatic multiple_pop_test();

begin
    error_count = 0;
    reset_dut();

    // Create initial occupancy = 6
    repeat(6)
        push();

    repeat(3)
        pop();

    check_count(3);
    note_case(error_count == 0);

end

endtask

// Full Test
task automatic full_test();

begin
    error_count = 0;
    reset_dut();

    // Fill counter up to DEPTH

    repeat(DEPTH)
        push();

    check_count(DEPTH);

    if(data_in_ready_o) begin

        $error("FULL TEST FAILED : ready should be LOW");
        error_count++;

    end
    note_case(error_count == 0);

end

endtask

// Empty Test
task automatic empty_test();

begin
    error_count = 0;
    reset_dut();

    check_count(0);

    if(data_out_valid_o) begin

        $error("EMPTY TEST FAILED : valid should be LOW");
        error_count++;

    end

    if(!data_in_ready_o) begin

        $error("EMPTY TEST FAILED : ready should be HIGH");
        error_count++;

    end

    note_case(error_count == 0);
end

endtask

// Overflow Test
task automatic overflow_test();

begin
    error_count = 0;
    reset_dut();

    repeat(DEPTH)
        push();

    check_count(DEPTH);

    // Try extra push
    push();
    $display("Attempted to push when full...."); 

    // Count should not increase
    check_count(DEPTH);
    note_case(error_count == 0);
end

endtask

// Underflow Test
task automatic underflow_test();

begin
    error_count = 0;
    reset_dut();

    check_count(0);

    // Try pop when empty
    pop();

    $display("Attempted to pop when empty....");
    // Count should remain zero

    check_count(0);
    note_case(error_count == 0);
end

endtask

// Simultaneous Push Pop Test
task automatic simultaneous_test();

begin
    error_count = 0;
    reset_dut();

    // Create initial occupancy = 4
    repeat(4)
        push();

    $display("Before simultaneous push_pop...");
    check_count(4);

    // One push and one pop together
    $display("Performing simultaneous push_pop...");
    push_pop();

    // Count should not change
    check_count(4);
    note_case(error_count == 0);

end

endtask

// Boundary Test (Empty and Full)
task automatic boundary_test();

begin
    error_count = 0;
    // Empty Boundary
    $display("\033[1;32mEMPTY BOUNDARY TEST:\033[0m");
    reset_dut();

    $display("EMPTY STATE : Expected=0 Got=%0d",
              count_o);

    if(data_out_valid_o) begin
        $error("EMPTY BOUNDARY FAILED : valid should be LOW");
        error_count++;
    end

    if(!data_in_ready_o) begin
        $error("EMPTY BOUNDARY FAILED : ready should be HIGH");
        error_count++;
    end

    // Push from empty

    push();

    $display("AFTER PUSH FROM EMPTY...");
    check_count(1);

    note_case(error_count == 0);

    // Full Boundary

    $display("\033[1;32mFULL BOUNDARY TEST:\033[0m");
    error_count = 0;
    reset_dut();

     $display("EMPTY STATE : Expected=0 Got=%0d",
              count_o);

    repeat(DEPTH)
        push();

    $display("FULL STATE : Expected=%0d Got=%0d",
              DEPTH,
              count_o);

    if(data_in_ready_o) begin
        $error("FULL BOUNDARY FAILED : ready should be LOW");
        error_count++;
    end

    if(!data_out_valid_o) begin
        $error("FULL BOUNDARY FAILED : valid should be HIGH");
        error_count++;
    end

    // Pop from full

    pop();

    $display("AFTER POP FROM FULL...");

    check_count(DEPTH-1);
    note_case(error_count == 0);

end

endtask


// Random Test

task automatic random_test();

int expected_count;
int i;

logic rand_in;
logic rand_out;

logic in_fire;
logic out_fire;

begin
    error_count = 0;
    reset_dut();

    expected_count = 0;
    i = 0;

    repeat(10) begin

        @(negedge clk_i);

        rand_in  = $urandom_range(0,1);
        rand_out = $urandom_range(0,1);

        data_in_valid_i  = rand_in;
        data_out_ready_i = rand_out;

        @(posedge clk_i);

        // Capture handshake of this cycle

        in_fire  = data_in_valid_i && data_in_ready_o;
        out_fire = data_out_valid_o && data_out_ready_i;

        // Update reference model

        case ({in_fire,out_fire})

            2'b10:
                expected_count++;

            2'b01:
                expected_count--;

            default:
                expected_count = expected_count;

        endcase

        #1;

        $display(
          "cycle=%0d in=%b out=%b expected=%0d got=%0d",
          i,
          in_fire,
          out_fire,
          expected_count,
          count_o
        );

        if(count_o !== expected_count) begin

            $error(
              "RANDOM ERROR cycle=%0d expected=%0d got=%0d",
              i,
              expected_count,
              count_o
            );
            error_count++;
        end
        i++;
    end

    data_in_valid_i  = 0;
    data_out_ready_i = 0;
  note_case(error_count == 0);

end

endtask
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
initial begin

    case(test_name)

        "reset": reset_test();
            
        "single_push": single_push_test();
            
        "multiple_push": multiple_push_test();
            
        "single_pop": single_pop_test();
            
        "multiple_pop": multiple_pop_test();
            
        "full": full_test();
            
        "empty": empty_test();
            
        "overflow": overflow_test();
            
        "underflow": underflow_test();
            
        "simultaneous": simultaneous_test();
                   
        "boundary": boundary_test();
            
        "random": random_test();
            
        default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);

      end
      
    endcase

    #100ns;

    $finish;

end
endmodule
  

