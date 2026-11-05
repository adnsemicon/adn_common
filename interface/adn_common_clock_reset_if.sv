/*

### Ports

| Name     | Direction | Description                           |
|----------|-----------|---------------------------------------|
| arst_n   | output    | Active-low asynchronous reset signal  |
| arst     | output    | Active-high asynchronous reset signal |
| clk      | output    | Generated primary clock signal        |
| clk_n    | output    | Inverted / complementary clock signal |

### Purpose
The `adn_common_clock_reset_if` interface provides a comprehensive, configurable SystemVerilog
simulation model and Bus Functional Model (BFM) for generating clock and reset signals. It
encapsulates clock frequency, duty cycle, phase offset, and active-low/active-high reset sequencing
into an intuitive, reusable interface for testbenches and verification environments.

### Use Case
This interface is primarily used in verification testbenches to eliminate boilerplate clock and reset generation logic. By providing standardized control tasks and functions (`start_clock`, `stop_clock`, `restart_clock`, `set_frequency`, `set_duty_cycle`, `apply_reset`, `apply_reset_cycles`, `wait_cycles`), verification environments can:
- **Simplify Testbench Setup:** Replace redundant `forever #half_period clk = ~clk;` and manual reset toggling with a parameterized, self-contained interface instance.
- **Dynamic Clock Control:** Dynamically adjust clock frequency and duty cycle during simulation to verify multi-rate designs, frequency scaling (DVFS), or clock gating behaviors.
- **Synchronous & Asynchronous Reset Generation:** Execute precise, glitch-free reset assertion and deassertion sequences defined by physical time delays or clock cycle counts.
- **Cycle-Accurate Synchronization:** Utilize built-in cycle counters (`clk_cycle_count`), edge alignment flags (`is_aligned`), and waiting utilities (`wait_cycles`, `wait_negedge_cycles`) for deterministic testbench stimulus and sampling.

| REVISION | DATE       | AUTHOR     | DESCRIPTION                                                 |
|----------|------------|------------|-------------------------------------------------------------|
| 0.1      | 2026-11-05 | Foez Ahmed | Initial version                                             |
| 1.0      | 2026-11-05 | Foez Ahmed | Stable release                                              |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of adnsemicon/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

interface adn_common_clock_reset_if #(

    //////////////////////////////////////////////
    // Reset parameters
    //////////////////////////////////////////////

    // 1: Active-low reset; 0: Active-high
    parameter bit RST_ACTIVE_LOW = 1'b1,
    // 1: Starts asserted at time 0
    parameter bit RST_START_ASSERTED = 1'b0,
    // Pre-reset delay before asserting reset
    parameter realtime RST_PRE_DURATION = 100ns,
    // Duration reset is held active
    parameter realtime RST_DURATION = 100ns,
    // Post-reset stabilization duration
    parameter realtime RST_POST_DURATION = 100ns,
    // 1: Auto-apply reset at time 0
    parameter bit AUTO_APPLY_RST = 1'b0,
    // Time at which the reset should auto-apply if enabled
    parameter realtime AUTO_APPLY_TIME    = 100ns,

    //////////////////////////////////////////////
    // Clock parameters
    //////////////////////////////////////////////

    // Default clock frequency in Hz
    parameter real CLK_FREQ = 100.0e6,
    // Default clock duty cycle percentage
    parameter real DUTY_CYCLE = 50.0,
    // Initial clock phase / start delay
    parameter realtime CLK_PHASE = 0ns,
    // Initial value before clock starts
    parameter bit CLK_START_VAL = 1'b0,
    // 1: Auto-start clock at time 0
    parameter bit AUTO_START_CLK = 1'b0,
    // Time at which the clock should auto-start if enabled
    parameter realtime AUTO_START_TIME = 500ns

) ();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic arst_n;  // Active-low asynchronous reset signal
  logic arst;  // Active-high asynchronous reset signal
  logic clk;  // Generated primary clock signal
  logic clk_n;  // Inverted / complementary clock signal

  assign arst  = ~arst_n;
  assign clk_n = ~clk;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  real             frequency = CLK_FREQ;
  real             duty_cycle = DUTY_CYCLE;
  bit              clock_enable = '0;
  bit              is_aligned;  // Synchronization flag pulsed high at posedge clk
  longint unsigned clk_cycle_count = '0;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MODPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // DUT modport: Connect directly to RTL design under test
  modport dut(input clk, input clk_n, input arst_n, input arst);

  // Driver modport: Full access to signals and control methods for testbench drivers
  modport driver(
      output clk,
      output clk_n,
      output arst_n,
      output arst,
      input clk_cycle_count,
      input is_aligned,
      import start_clock,
      import stop_clock,
      import restart_clock,
      import set_frequency,
      import set_duty_cycle,
      import set_clock_enable,
      import apply_reset,
      import apply_reset_cycles,
      import assert_reset,
      import deassert_reset,
      import wait_cycles,
      import wait_negedge_cycles,
      import wait_for_reset_done,
      import reset_cycle_count,
      import get_frequency,
      import get_period,
      import get_duty_cycle,
      import is_reset_asserted
  );

  // Monitor modport: Passive observation of clock, resets, and cycle counter
  modport monitor(
      input clk,
      input clk_n,
      input arst_n,
      input arst,
      input clk_cycle_count,
      input is_aligned,
      import wait_cycles,
      import wait_negedge_cycles,
      import wait_for_reset_done,
      import get_frequency,
      import get_period,
      import get_duty_cycle,
      import is_reset_asserted
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Clock cycle counter
  always @(posedge clk) begin
    clk_cycle_count <= clk_cycle_count + 1'b1;
  end

  // Clock edge alignment pulse (useful for race-free stimulus driving and sampling)
  always @(posedge clk) begin
    is_aligned = 1'b1;
    #1step;
    is_aligned = 1'b0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK GENERATION PROCESS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin : clk_gen_proc
    clk = CLK_START_VAL;
    if (CLK_PHASE > 0) #(CLK_PHASE);

    forever begin
      wait (clock_enable);
      while (clock_enable) begin
        realtime t_period;
        realtime t_high;
        realtime t_low;

        t_period = (frequency > 0.0) ? (1.0s / frequency) : 10ns;
        t_high   = t_period * (duty_cycle / 100.0);
        t_low    = t_period - t_high;

        clk <= 1'b1;
        #(t_high);
        if (!clock_enable) begin
          clk <= 1'b0;
          break;
        end
        clk <= 1'b0;
        #(t_low);
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RESET INITIALIZATION PROCESS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin : rst_gen_proc
    if (RST_START_ASSERTED) begin
      arst_n = RST_ACTIVE_LOW ? 1'b0 : 1'b1;
    end else begin
      arst_n = RST_ACTIVE_LOW ? 1'b1 : 1'b0;
    end

    fork

      if (AUTO_APPLY_RST) begin
        #(AUTO_APPLY_TIME);
        apply_reset(RST_DURATION, RST_POST_DURATION, RST_PRE_DURATION);
      end

      if (AUTO_START_CLK) begin
        #(AUTO_START_TIME);
        clock_enable = 1'b1;
      end
    join
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Configure clock frequency dynamically (Hz)
  function automatic bit set_frequency(input real freq = 100.0e6);
    if (freq > 0.0) begin
      frequency = freq;
      return 1'b1;
    end else begin
      return 1'b0;
    end
  endfunction

  // Configure clock duty cycle dynamically (percentage: 0.0 < duty < 100.0)
  function automatic bit set_duty_cycle(input real duty = 50.0);
    if (duty > 0.0 && duty < 100.0) begin
      duty_cycle = duty;
      return 1'b1;
    end else begin
      return 1'b0;
    end
  endfunction

  // Enable or disable clock generation
  function automatic bit set_clock_enable(input bit enable);
    clock_enable = enable;
    if (!enable) begin
      clk = 1'b0;
    end
    return 1'b1;
  endfunction

  // Start clock generator, optionally specifying frequency and duty cycle
  task automatic start_clock(input real freq = 0.0, input real duty = 0.0);
    if (freq > 0.0) begin
      void'(set_frequency(freq));
    end else if (frequency <= 0.0) begin
      frequency = CLK_FREQ;
    end

    if (duty > 0.0 && duty < 100.0) begin
      void'(set_duty_cycle(duty));
    end else if (duty_cycle <= 0.0 || duty_cycle >= 100.0) begin
      duty_cycle = DUTY_CYCLE;
    end

    if (!clock_enable) begin
      clock_enable = 1'b1;
    end
    @(posedge clk);
  endtask

  // Stop clock generator safely (by default waiting for negedge clk to prevent runt pulses)
  task automatic stop_clock(input bit wait_for_negedge = 1'b1);
    if (!clock_enable) return;
    if (wait_for_negedge && clk === 1'b1) begin
      @(negedge clk);
    end
    clock_enable = 1'b0;
    clk <= 1'b0;
  endtask

  // Restart clock after being stopped
  task automatic restart_clock();
    if (!clock_enable) begin
      clock_enable = 1'b1;
    end
    @(posedge clk);
  endtask

  // Apply asynchronous reset sequence with configurable phases
  task automatic apply_reset(input realtime reset_duration = RST_DURATION,
                             input realtime post_reset_duration = reset_duration,
                             input realtime pre_reset_duration = post_reset_duration,
                             input bit stop_clock_during_reset = 1'b0);
    bit prev_clock_enable;
    prev_clock_enable = clock_enable;

    if (stop_clock_during_reset && clock_enable) begin
      stop_clock();
    end

    if (pre_reset_duration > 0) #(pre_reset_duration);
    arst_n <= RST_ACTIVE_LOW ? 1'b0 : 1'b1;
    #(reset_duration);
    arst_n <= RST_ACTIVE_LOW ? 1'b1 : 1'b0;
    if (post_reset_duration > 0) #(post_reset_duration);

    if (stop_clock_during_reset && prev_clock_enable) begin
      start_clock();
    end
  endtask

  // Apply reset synchronously for a specified number of clock cycles
  task automatic apply_reset_cycles(input int unsigned reset_cycles = 10,
                                    input int unsigned post_reset_cycles = 10,
                                    input int unsigned pre_reset_cycles = 0);
    if (!clock_enable) begin
      $display("[%0t] [WARNING] %m: apply_reset_cycles called with clock stopped! Starting clock.",
               $realtime);
      start_clock();
    end

    if (pre_reset_cycles > 0) repeat (pre_reset_cycles) @(posedge clk);
    arst_n <= RST_ACTIVE_LOW ? 1'b0 : 1'b1;
    repeat (reset_cycles) @(posedge clk);
    arst_n <= RST_ACTIVE_LOW ? 1'b1 : 1'b0;
    if (post_reset_cycles > 0) repeat (post_reset_cycles) @(posedge clk);
  endtask

  // Assert reset immediately
  task automatic assert_reset();
    arst_n <= RST_ACTIVE_LOW ? 1'b0 : 1'b1;
  endtask

  // Deassert reset immediately
  task automatic deassert_reset();
    arst_n <= RST_ACTIVE_LOW ? 1'b1 : 1'b0;
  endtask

  // Wait for N rising clock edges
  task automatic wait_cycles(input int unsigned count = 1);
    repeat (count) @(posedge clk);
  endtask

  // Wait for N falling clock edges
  task automatic wait_negedge_cycles(input int unsigned count = 1);
    repeat (count) @(negedge clk);
  endtask

  // Wait until reset is deasserted
  task automatic wait_for_reset_done();
    if (RST_ACTIVE_LOW) begin
      wait (arst_n === 1'b1);
    end else begin
      wait (arst_n === 1'b0);
    end
  endtask

  // Reset the cycle counter
  function automatic void reset_cycle_count();
    clk_cycle_count = '0;
  endfunction

  // Query functions
  function automatic real get_frequency();
    return frequency;
  endfunction

  function automatic realtime get_period();
    return (frequency > 0.0) ? (1.0s / frequency) : 10ns;
  endfunction

  function automatic real get_duty_cycle();
    return duty_cycle;
  endfunction

  function automatic bit is_reset_asserted();
    return (arst_n === (RST_ACTIVE_LOW ? 1'b0 : 1'b1));
  endfunction

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    if (CLK_FREQ <= 0.0) begin
      $error("%m: CLK_FREQ parameter must be greater than 0. Received: %f", CLK_FREQ);
    end
    if (DUTY_CYCLE <= 0.0 || DUTY_CYCLE >= 100.0) begin
      $error("%m: DUTY_CYCLE parameter must be in range (0.0, 100.0). Received: %f", DUTY_CYCLE);
    end
    if (RST_DURATION <= 0) begin
      $warning("%m: RST_DURATION parameter should be greater than 0. Received: %0t", RST_DURATION);
    end
  end

endinterface
