module MazeRunner_tb_integrated_right();

  reg clk, RST_n;
  reg send_cmd;                 // assert to send command to MazeRunner
  reg [15:0] cmd;               // 16-bit command to send
  reg [11:0] batt;              // battery voltage 0xD80 is nominal

  logic cmd_sent;
  logic resp_rdy;               // MazeRunner has sent a pos acknowledge
  logic [7:0] resp;             // resp byte from MazeRunner (hopefully 0xA5)
  logic clr_resp_rdy;           // TB clears resp_rdy after consuming each ack
  logic hall_n;                 // magnet found?

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

  // COMMANDS
  localparam logic [15:0] CALIBRATE    = 16'h0000,
                          HEADING_BASE = 16'h2000,
                          MOVE_BASE    = 16'h4000,
                          SOLVE_BASE   = 16'h6000;
  // DIRECTIONS
  localparam logic [11:0] NORTH = 12'h000,
                          WEST  = 12'h3FF,
                          SOUTH = 12'h7FF,
                          EAST  = 12'hC00;
  // MOVE STOP CONDITIONS
  localparam logic [1:0] STP_RGHT = 2'b01,
                         STP_LFT  = 2'b10;
  //  SOLVE AFFINITY CONDITIONS
  localparam logic LFT_AFFN  = 1'b1,
                   RGHT_AFFN = 1'b0;

  /* Helper task to initialize and reset the testbench */
  task initialize_and_reset;
    clk          = 1'b0;
    RST_n        = 1'b0;
    send_cmd     = 1'b0;
    cmd          = 16'h0000;
    batt         = 12'hD80;        // nominal battery voltage
    clr_resp_rdy = 1'b0;
    @(posedge clk);
    @(negedge clk);
    RST_n = 1'b1;                  // release reset
  endtask

  /* Helper task to send a command */
  task send_command(input logic [15:0] cmd_to_send);
    @(negedge clk);
    cmd      = cmd_to_send;
    send_cmd = 1'b1;               // pulse send command
    @(negedge clk);
    send_cmd = 1'b0;
    // Wait until RemoteComm has finished shifting both bytes onto the wire
    // before returning, so the next send_command call doesn't race.
    @(posedge cmd_sent);
  endtask

  /* Wait (with a configurable cycle budget) for a positive (0xA5) ack */
  task check_for_ack(input int max_cycles, input string label);
    fork
      begin: wait_for_ack
        wait(resp_rdy);
        disable ack_time_out;       // got an ack -> kill the watchdog
        if (resp !== 8'hA5) begin
          $display("[%0t] %s: Expected 8'hA5 as response, but got %h",
                   $time, label, resp);
          $stop();
        end else begin
          $display("[%0t] %s: 0xA5 ack received", $time, label);
          @(negedge clk);
          clr_resp_rdy = 1'b1;      // consume the ack so resp_rdy can rearm
          @(negedge clk);
          clr_resp_rdy = 1'b0;
        end
      end

      begin: ack_time_out
        repeat (max_cycles) @(negedge clk);
        $display("[%0t] %s: Did not receive 0xA5 ack within %0d cycles",
                 $time, label, max_cycles);
        $stop();
      end
    join
  endtask

  /* Global watchdog so the TB never hangs forever */
  initial begin: global_timeout
    #200_000_000;
    $display("[%0t] GLOBAL TB TIMEOUT", $time);
    $stop();
  end

  initial begin

    /// Setup ///
    initialize_and_reset();

    // ------------------------------------------------------------------
    // 1) Calibration: send 0x0000 and wait for the 0xA5 acknowledgement.
    //    Calibration with FAST_SIM=1 takes ~80k clk cycles after cmd_sent;
    //    we give it 2M cycles of headroom.  check_for_ack also clears
    //    resp_rdy so the next ack is recognized cleanly.
    // ------------------------------------------------------------------
    send_command(CALIBRATE);
    check_for_ack(2_000_000, "CAL");

    // ------------------------------------------------------------------
    // 2) Idle / sanity probes BEFORE issuing any motion command.
    //    During calibration the wheels are not driven, so:
    //      - PID outputs lft_spd/rght_spd should still be 0
    //      - RunnerPhysics omega_sum (= omega_lft + omega_rght) should be 0
    //    Any non-zero value would mean the design or the plant model
    //    started moving on their own.
    // ------------------------------------------------------------------
    if (iDUT.lft_spd !== 12'h000 || iDUT.rght_spd !== 12'h000) begin
      $display("[%0t] ERR: lft_spd/rght_spd not zero during idle (%h/%h)",
               $time, iDUT.lft_spd, iDUT.rght_spd);
      $stop();
    end
    if (iPHYS.omega_sum !== 17'h00000) begin
      $display("[%0t] ERR: RunnerPhysics omega_sum non-zero during idle (=%h)",
               $time, iPHYS.omega_sum);
      $stop();
    end
    $display("[%0t] CHK: robot is stationary post-calibration", $time);

    // ------------------------------------------------------------------
    // 3) Sanity move: ask the robot to drive due north.  At start the
    //    robot is in cell (3,3) which has NEW walls (mazeModel[3][3]=4'hB),
    //    so the move will hit the north wall almost immediately,
    //    navigate's MV_ACCEL -> DECEL_FAST will fire mv_cmplt, and
    //    cmd_proc will reply with 0xA5.  The point is to confirm that:
    //       (a) cmd_proc actually issues strt_mv after a MOVE command,
    //       (b) the response path still works.
    // ------------------------------------------------------------------
    send_command(MOVE_BASE | NORTH);

    // Watch for strt_mv with a small budget so we don't miss the pulse
    // and don't hang if it never asserts.
    fork: chk_strt_mv
      begin
        wait(iDUT.strt_mv);
        $display("[%0t] CHK: strt_mv asserted after MOVE command", $time);
        disable strt_mv_to;
      end
      begin: strt_mv_to
        repeat (100_000) @(negedge clk);
        $display("[%0t] ERR: strt_mv was never asserted after MOVE command",
                 $time);
        $stop();
      end
    join

    check_for_ack(5_000_000, "MOVE NORTH (wall)");

    // ------------------------------------------------------------------
    // 4) Start the RIGHT-affinity maze solve.
    //    cmd_proc latches cmd_md=0, maze_solve takes over the navigate
    //    interface, and from here on we just observe the navigation
    //    milestones (mv_cmplt) and the magnet event (hall_n -> 0).
    // ------------------------------------------------------------------
    $display("[%0t] --- Starting RIGHT-affinity maze solve ---", $time);
    send_command(SOLVE_BASE | RGHT_AFFN);

    // ------------------------------------------------------------------
    // Milestone counter.  Cell (3,3) has NEW walls so left, right and
    // forward are all blocked at start regardless of affinity.  The
    // first mv_cmplt is therefore still the failed forward attempt at
    // the north wall (heading=NORTH), and SOL_CHECK still resolves to a
    // 180-degree turn (no left or right opening for either affinity).
    // The U-turn completes on the SECOND mv_cmplt (heading=SOUTH), and
    // the first southbound forward cell finishes on the THIRD mv_cmplt
    // (yy[14:8] ~= 0x28).  After that the right-affinity algorithm
    // diverges from the left-affinity one at the next intersection.
    // ------------------------------------------------------------------
    begin: drive_solve
      int mv_count;
      mv_count = 0;

      // milestone #1: forward into north wall
      @(posedge iDUT.mv_cmplt);
      mv_count++;
      $display("[%0t] mv_cmplt #1 (forward attempt vs. north wall): heading=%h",
               $time, iPHYS.heading_robot[19:8]);

      // milestone #2: U-turn complete (heading should now be ~SOUTH)
      @(posedge iDUT.mv_cmplt);
      mv_count++;
      // heading_robot is signed; SOUTH is the 0x7FF/0x800 wrap region.
      if (!(iPHYS.heading_robot[19:8] inside {[12'h750:12'h7FF], [12'h800:12'h850]})) begin
        $display("[%0t] ERR: Expected U-Turn to SOUTH after mv_cmplt #2, got heading %h",
                 $time, iPHYS.heading_robot[19:8]);
        $stop();
      end
      $display("[%0t] CHK: U-turn complete, robot facing SOUTH (heading=%h)",
               $time, iPHYS.heading_robot[19:8]);

      // milestone #3: first southbound forward move complete (yy ~= 0x28)
      @(posedge iDUT.mv_cmplt);
      mv_count++;
      $display("[%0t] mv_cmplt #3: xx=%h yy=%h (target yy[14:8]~=0x28)",
               $time, iPHYS.xx[14:8], iPHYS.yy[14:8]);

      // ----------------------------------------------------------------
      // 5) Let the RIGHT-affinity algorithm run autonomously and log
      //    every additional milestone until the magnet (hall_n=0) is
      //    detected.  hall_n is asserted by RunnerPhysics when (xx,yy)
      //    falls inside the +/-3 window around (magnet_pos_xx,
      //    magnet_pos_yy) = (0x18, 0x28), i.e. cell (1,2).
      // ----------------------------------------------------------------
      $display("[%0t] Monitoring autonomous right-affinity navigation...",
               $time);
      while (hall_n === 1'b1) begin
        @(posedge iDUT.mv_cmplt);
        mv_count++;
        if (hall_n === 1'b1) begin
          $display("[%0t]   -> milestone #%0d | xx=%h yy=%h heading=%h",
                   $time, mv_count, iPHYS.xx[14:8], iPHYS.yy[14:8],
                   iPHYS.heading_robot[19:8]);
        end
      end

      $display("[%0t] SUCCESS: hall_n went low after %0d milestones (xx=%h, yy=%h)",
               $time, mv_count, iPHYS.xx[14:8], iPHYS.yy[14:8]);
    end

    // ------------------------------------------------------------------
    // 6) Final SOLVE-complete ack.  cmd_proc's SOLVE arm asserts
    //    send_resp once sol_cmplt rises, RemoteComm latches resp_rdy
    //    with resp == 0xA5.
    // ------------------------------------------------------------------
    check_for_ack(2_000_000, "SOLVE RIGHT");

    $display("---------------------------------------------------------------");
    $display("[%0t] RIGHT-AFFINITY INTEGRATED TEST PASSED", $time);
    $display("---------------------------------------------------------------");

    disable global_timeout;
    $stop();
  end

  always
    #5 clk = ~clk;

endmodule
