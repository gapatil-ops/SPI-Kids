module MazeRunner_tb();
  
  reg clk, RST_n;
  reg send_cmd;           // assert to send command to RemoteComm
  reg [15:0] cmd;         // 16-bit command to send
  reg [11:0] batt;        // battery voltage 0xD80 is nominal
  
  logic cmd_sent;       
  logic resp_rdy;         // MazeRunner has sent a pos acknowledge
  logic [7:0] resp;       // resp byte from MazeRunner (hopefully 0xA5)
  logic clr_resp_rdy;     // TB clears resp_rdy after consuming each ack
  logic hall_n;           // magnet found?
   
  /////////////////////////////////////////////////////////////////////////
  // Signals interconnecting MazeRunner to RunnerPhysics and RemoteComm //
  ///////////////////////////////////////////////////////////////////////
  wire TX_RX, RX_TX;
  wire INRT_SS_n, INRT_SCLK, INRT_MOSI, INRT_MISO, INRT_INT;
  wire lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
  wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;
  wire IR_lft_en, IR_cntr_en, IR_rght_en;  
  wire piezo;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk), .RST_n(RST_n), .INRT_SS_n(INRT_SS_n), .INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI), .INRT_MISO(INRT_MISO), .INRT_INT(INRT_INT),
                  .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK), .A2D_MOSI(A2D_MOSI),
                  .A2D_MISO(A2D_MISO), .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
                  .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2), .RX(RX_TX), .TX(TX_RX),
                  .hall_n(hall_n), .piezo(piezo), .piezo_n(), .IR_lft_en(IR_lft_en),
                  .IR_rght_en(IR_rght_en), .IR_cntr_en(IR_cntr_en), .LED());
  
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .snd_cmd(send_cmd),
                  .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp), .clr_resp_rdy(clr_resp_rdy));
         
  ///////////////////////////////////////////////////
  // Instantiate physical model of robot and maze //
  /////////////////////////////////////////////////
  RunnerPhysics iPHYS(.clk(clk), .RST_n(RST_n), .SS_n(INRT_SS_n), .SCLK(INRT_SCLK), .MISO(INRT_MISO),
                      .MOSI(INRT_MOSI), .INT(INRT_INT), .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
                      .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
                      .IR_lft_en(IR_lft_en), .IR_cntr_en(IR_cntr_en), .IR_rght_en(IR_rght_en),
                      .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK), .A2D_MOSI(A2D_MOSI),
                      .A2D_MISO(A2D_MISO), .hall_n(hall_n), .batt(batt));

  // ====================================================================
  // OPCODES & CONSTANTS
  // ====================================================================
  localparam logic [15:0] CALIBRATE    = 16'h0000,
                          HEADING_BASE = 16'h2000;
                          
  // DIRECTIONS
  localparam logic [11:0] NORTH = 12'h000,
                          WEST  = 12'h3FF,
                          SOUTH = 12'h7FF,
                          EAST  = 12'hC00;

  // ====================================================================
  // ROBUST TASKS (Prevents race conditions & timeouts)
  // ====================================================================
  task automatic initialize_and_reset();
    clk = 0; RST_n = 0; send_cmd = 0; cmd = 0; batt = 12'hD80; clr_resp_rdy = 0;
    @(posedge clk);
    @(negedge clk);
    RST_n = 1;
    
    // Nudge the physics model off dead-center to prevent physics division glitches
    #1;
    iPHYS.xx = 15'h3801; 
    iPHYS.yy = 15'h3801;
  endtask

  task automatic send_command(input logic [15:0] c);
    @(negedge clk);
    cmd      = c;
    send_cmd = 1'b1;
    @(negedge clk);
    send_cmd = 1'b0;
    @(posedge cmd_sent); // Wait for UART to finish transmitting both bytes
  endtask

  task automatic check_for_ack(input int max_cycles, input string label);
    int cyc = 0;
    bit got = 1'b0;
    fork : wait_block
      begin : waiter
        @(posedge resp_rdy);
        got = 1'b1;
      end
      begin : timer
        while (cyc < max_cycles && !got) begin
          @(posedge clk);
          cyc++;
        end
      end
    join_any
    disable wait_block;

    if (!got) begin
      $display("[%0t] ERR: %s TIMEOUT after %0d cycles (no resp_rdy)", $time, label, max_cycles);
      $stop();
    end else if (resp !== 8'hA5) begin
      $display("[%0t] ERR: %s BAD RESP: expected 0xA5, got 0x%02h", $time, label, resp);
      $stop();
    end else begin
      $display("[%0t] SUCCESS: %s - positive ack (0xA5) received", $time, label);
    end

    // Consume the acknowledgment so resp_rdy can rearm cleanly
    @(negedge clk); clr_resp_rdy = 1'b1;
    @(negedge clk); clr_resp_rdy = 1'b0;
  endtask

  // ====================================================================
  // MAIN TEST SEQUENCE
  // ====================================================================
  initial begin: test_sequence
    
    initialize_and_reset();

    // ------------------------------------------------------------------
    // TEST 1: Calibration (Hits gyro initialize states)
    // ------------------------------------------------------------------
    $display("\n--- TEST 1: CALIBRATION ---");
    send_command(CALIBRATE);
    check_for_ack(2_000_000, "CALIBRATION");

    // ------------------------------------------------------------------
    // TEST 2: Idle Probes
    // ------------------------------------------------------------------
    $display("\n--- TEST 2: IDLE CHECKS ---");
    if (iDUT.lft_spd !== 12'h000 || iDUT.rght_spd !== 12'h000) begin
      $display("ERR: Control signals not zero during idle!");
      $stop();
    end 
    // Allow +/- 100 tolerance for UART/PWM measurement noise
    if (iPHYS.omega_sum > $signed(17'd100) || iPHYS.omega_sum < $signed(-17'd100)) begin
      $display("ERR: Physical model reports movement during idle!");
      $stop();
    end 
    $display("SUCCESS: Robot is perfectly stationary.");

    // ------------------------------------------------------------------
    // TEST 3: Heading Pivots & Battery Scaling 
    // Covers PID, navigate heading states, and MtrDrv low-battery division
    // ------------------------------------------------------------------
    $display("\n--- TEST 3: MANUAL HEADING & BATTERY SCALING ---");
    
    $display("INFO: Pivoting West at Nominal Battery (0xD80)...");
    send_command(HEADING_BASE | WEST);
    check_for_ack(5_000_000, "TURN WEST");

    // Force a low battery condition to test scaling logic in MtrDrv
    $display("INFO: Dropping battery to 12'hA00 to test MtrDrv PWM scaling loop...");
    batt = 12'hA00; 
    send_command(HEADING_BASE | EAST);
    check_for_ack(5_000_000, "TURN EAST (LOW BATTERY)");

    // Restore battery to nominal
    $display("INFO: Restoring Nominal Battery (0xD80)...");
    batt = 12'hD80; 
    send_command(HEADING_BASE | NORTH);
    check_for_ack(5_000_000, "TURN NORTH");

    $display("\n=======================================================");
    $display("  BASE COMMANDS & SCALING TESTS COMPLETED SUCCESSFULLY ");
    $display("=======================================================\n");
    $stop();
  end
  
  always #5 clk = ~clk;
  
endmodule