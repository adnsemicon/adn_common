/*

FILE: adn_common_tb_headers.sv

### Purpose
This file contains common testbench headers and utility functions for ADN Common modules. This file
is intended to be included in testbenches to provide standardized logging, test case tracking, and
simulation control. This module provides global variables and functions to track the number of
passed and failed test cases, as well as to manage simulation parameters such as test name, test
count, VCD generation, and debug mode.

### Use Case
This file is included in testbenches for ADN Common modules to provide a consistent framework for
running tests, logging results, and generating VCD files for waveform analysis. It allows
testbenches to easily track the number of passed and failed test cases, manage simulation
parameters, and provide clear output at the start and end of simulations.

| Variable                | Description                                                                                 |
| ----------------------- | ------------------------------------------------------------------------------------------- |
| `longint passed_cases;` | Counter for the number of passed test cases                                                 |
| `longint failed_cases;` | Counter for the number of failed test cases                                                 |
| `string top_name;`      | Name of the top module being simulated                                                      |
| `string test_name;`     | Name of the test being executed, can be set via command line argument "TN"                  |
| `int test_count;`       | Number of test iterations to run, can be set via command line argument "TC"                 |
| `int vcd;`              | Flag to indicate whether to generate VCD file, can be set via command line argument "VCD"   |
| `int debug;`            | Flag to indicate whether to enable debug mode, can be set via command line argument "DEBUG" |

Use `note_case(1);` to note a passed test case and `note_case(0);` to note a failed test case. The
final result of the test will be displayed at the end of the simulation, indicating whether all
test cases passed or if there were any failures.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0      | 2026-07-20 | Foez Ahmed      | Stable release                                         |
| 1.1      | 2026-08-01 | Foez Ahmed      | Ratified                                               |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of https://github.com/adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// Marks the start of Simulation
initial $display("\033[7;38m################ TEST STARTED ################\033[0m");

////////////////////////////////////////////////////////////////////////////////////////////////////
// GLOBAL VARIABLES
////////////////////////////////////////////////////////////////////////////////////////////////////

// Counter for the number of passed test cases
longint passed_cases;
// Counter for the number of failed test cases
longint failed_cases;

// Name of the top module being simulated
string top_name;
// Name of the test being executed, can be set via command line argument "TN"
string test_name;
// Number of test iterations to run, can be set via command line argument "TC"
int test_count;
// Flag to indicate whether to generate VCD file, can be set via command line argument "VCD"
int vcd;
// Flag to indicate whether to enable debug mode, can be set via command line argument "DEBUG"
int debug;

covergroup test_report_group with function sample (bit case_ok);
  coverpoint case_ok {bins pass = {1}; illegal_bins fail = {0};}
endgroup

test_report_group test_report = new();

// Function to note the result of a test case. Increments the passed_cases or failed_cases counter
// based on the pass parameter.
function automatic void note_case(bit pass);
  if (pass) passed_cases++;
  else failed_cases++;
  test_report.sample(pass);
endfunction

initial begin

  // Set the time format for simulation output to nanoseconds with no decimal places
  $timeformat(-9, 0, "ns");

  // Get the top module name for logging purposes
  top_name = $sformatf("%m");

  // Get the test name from command line arguments, default to "default" if not provided
  if (!$value$plusargs("TN=%s", test_name)) begin
    test_name = "default";
  end

  // Get the test count from command line arguments, default to 1 if not provided
  if (!$value$plusargs("TC=%d", test_count)) begin
    test_count = 1;
  end

  // Get the VCD generation flag from command line arguments, default to 0 (no VCD) if not provided
  if (!$value$plusargs("VCD=%d", vcd)) begin
    vcd = 0;
  end

  // Generate VCD file if requested
  if (vcd) begin
    $dumpfile($sformatf("%s.vcd", top_name));
    $dumpvars(0);
  end

  // Get the debug flag from command line arguments, default to 0 (no debug) if not provided
  if (!$value$plusargs("DEBUG=%d", debug)) begin
    debug = 0;
  end

  // Display the simulation parameters for logging purposes
  $display("SIMULATING TOP: %s, TEST: %s, COUNT: %0d, VCD: %0d, DEBUG: %0d", top_name, test_name,
           test_count, vcd, debug);

end

final begin

  // Marks the end of Simulation
  $display("\033[7;38m################# TEST ENDED #################\033[0m");

  // Display the number of passed and failed test cases
  $display("PASSED CASES: %0d, FAILED CASES: %0d", passed_cases, failed_cases);

  // Display the final test result based on the number of passed and failed cases
  if (failed_cases == 0 && passed_cases != 0) begin
    $display("\033[1;32mTEST PASSED\033[0m");
  end else begin
    $display("\033[1;31mTEST FAILED\033[0m");
  end

end
