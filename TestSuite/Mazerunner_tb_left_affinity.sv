////////////////////////////////////////////////////////////////////////////////
// MazeRunner_tb_left_affinity
//
// Incremental left-affinity testbench.  The order of checks is:
//   1) Calibration : send 0x0000, expect a 0xA5 positive ack from cmd_proc.
//   2) Affinity selection (cmd[0]=1 -> left affinity):
//        - maze_solve drives stp_lft = cmd0,  stp_rght = ~cmd0
//        - so cmd[0]=1 must produce stp_lft=1, stp_rght=0
//        - the muxed iDUT.stp_lft/stp_rght (cmd_md ? cmd : slv) should also
//          flip over to the solver's values once cmd_md drops.
//   3) Forward motion:
//        - In maze_solve.MOVE state, MOVE -> SOL_CHECK only fires when
//          (lft_opn & cmd0) | (rght_opn & ~cmd0) | mv_cmplt.  With all three
//          inputs deasserted (no openings to take, no obstruction reached)
//          the FSM must remain in MOVE so navigate keeps driving forward.
//   4) Three left-affinity turn cases (each forced independently):
//        a) Left opening present  ->  dsrd_hdng += 0x400 (turn left)
//        b) No left, right open + mv_cmplt -> dsrd_hdng -= 0x400 (turn right)
//        c) Dead end (no openings) + mv_cmplt -> dsrd_hdng += 0x800 (180)
//
// We use force/release on iDUT.iSLV.{lft_opn, rght_opn, mv_cmplt} so the
// algorithm can be exercised deterministically without depending on the
// robot's exact location in the modeled maze.
////////////////////////////////////////////////////////////////////////////////
module MazeRunner_tb_left_affinity();

  //////////////////////////////////////////////////////////////////////////////
  // Stimulus & observation signals
  //////////////////////////////////////////////////////////////////////////////
  reg          clk, RST_n;
  reg          send_cmd;           // assert to send a command via RemoteComm
  reg  [15:0]  cmd;                // 16-bit command to send
  reg  [11:0]  batt;               // battery voltage (0xD80 nominal)

  logic        cmd_sent;           // from RemoteComm: both bytes transmitted
  logic        resp_rdy;           // from RemoteComm: response byte latched
  logic [7:0]  resp;               // response byte (expect 0xA5 for pos ack)
  logic        clr_resp_rdy;       // TB-driven handshake clearing resp_rdy
  logic        hall_n;             // from RunnerPhysics: magnet found (active low)

  // Nets between MazeRunner, RunnerPhysics, and RemoteComm
  wire TX_RX, RX_TX;
  wire INRT_SS_n, INRT_SCLK, INRT_MOSI, INRT_MISO, INRT_INT;
  wire lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
  wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;
  wire IR_lft_en, IR_cntr_en, IR_rght_en;
  wire piezo;

  //////////////////////////////////////////////////////////////////////////////
  // Local mirror of maze_solve's state encoding (typedef inside iSLV is
  // { IDLE, MOVE, SOL_CHECK, DONE } -> 2'd0..2'd3).  We use these to assert
  // FSM positions from outside without relying on hierarchical enum access.
  //////////////////////////////////////////////////////////////////////////////
  localparam logic [1:0] IDLE_S      = 2'd0;
  localparam logic [1:0] MOVE_S      = 2'd1;
  localparam logic [1:0] SOL_CHECK_S = 2'd2;
  localparam logic [1:0] DONE_S      = 2'd3;

  //////////////////////////////////////////////////////////////////////////////
  // Local mirror of piezo_drv's state encoding (typedef inside ICHRG is
  // { IDLE, G6_M, C7_M, E7_M, G7_M_L, E7_L, G7_H } -> 3'd0..3'd6).  These
  // are used by STEP 6 to walk the piezo FSM through the full "Charge!"
  // fanfare when the magnet is "found".  Note that the G7_M_L/E7_L/G7_H
  // trio is only ever reached when batt_low=0 AND fanfare=1 (a low-battery
  // beep, by contrast, stops after the first three notes), so reaching
  // G7_H is the unambiguous proof that the magnet-found fanfare path was
  // taken.
  //////////////////////////////////////////////////////////////////////////////
  localparam logic [2:0] PIEZO_IDLE_S   = 3'd0;
  localparam logic [2:0] PIEZO_G6_M_S   = 3'd1;
  localparam logic [2:0] PIEZO_C7_M_S   = 3'd2;
  localparam logic [2:0] PIEZO_E7_M_S   = 3'd3;
  localparam logic [2:0] PIEZO_G7_M_L_S = 3'd4;
  localparam logic [2:0] PIEZO_E7_L_S   = 3'd5;
  localparam logic [2:0] PIEZO_G7_H_S   = 3'd6;

  // Latches the first time we ever see strt_mv assert.  Used by the forward-
  // motion check to confirm maze_solve actually pulsed strt_mv when leaving
  // IDLE (i.e., navigate was kicked off into the moving state).
  logic seen_strt_mv;
  // Static force-drive values.  We cannot force from automatic task arguments
  // in Questa, so ForceMazeInputs copies requested values here first and then
  // forces iSLV inputs from these static logic signals.
  logic force_lft_opn, force_rght_opn, force_mv_cmplt;
  always_ff @(posedge clk or negedge RST_n) begin
    if (!RST_n)
      seen_strt_mv <= 1'b0;
    else if (iDUT.iSLV.strt_mv)
      seen_strt_mv <= 1'b1;
  end

  //////////////////////////////////////////////////////////////////////////////
  // Instantiate DUT
  //////////////////////////////////////////////////////////////////////////////
  MazeRunner iDUT(.clk(clk), .RST_n(RST_n),
                  .INRT_SS_n(INRT_SS_n), .INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI), .INRT_MISO(INRT_MISO),
                  .INRT_INT(INRT_INT),
                  .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK),
                  .A2D_MOSI(A2D_MOSI), .A2D_MISO(A2D_MISO),
                  .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
                  .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
                  .RX(RX_TX), .TX(TX_RX),
                  .hall_n(hall_n), .piezo(piezo), .piezo_n(),
                  .IR_lft_en(IR_lft_en), .IR_rght_en(IR_rght_en),
                  .IR_cntr_en(IR_cntr_en), .LED());

  //////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm (bluetooth proxy).  clr_resp_rdy is driven by the
  // TB (see ChkPosAck below) so each response from the DUT produces a fresh
  // posedge on resp_rdy.
  //////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n),
                  .RX(TX_RX), .TX(RX_TX),
                  .cmd(cmd), .snd_cmd(send_cmd),
                  .cmd_sent(cmd_sent),
                  .resp_rdy(resp_rdy), .resp(resp),
                  .clr_resp_rdy(clr_resp_rdy));

  //////////////////////////////////////////////////////////////////////////////
  // Instantiate physical model of the robot and the maze
  //////////////////////////////////////////////////////////////////////////////
  RunnerPhysics iPHYS(.clk(clk), .RST_n(RST_n),
                      .SS_n(INRT_SS_n), .SCLK(INRT_SCLK),
                      .MISO(INRT_MISO), .MOSI(INRT_MOSI), .INT(INRT_INT),
                      .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
                      .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
                      .IR_lft_en(IR_lft_en), .IR_cntr_en(IR_cntr_en),
                      .IR_rght_en(IR_rght_en),
                      .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK),
                      .A2D_MOSI(A2D_MOSI), .A2D_MISO(A2D_MISO),
                      .hall_n(hall_n), .batt(batt));

  //////////////////////////////////////////////////////////////////////////////
  // Readable stimulus tasks (per spec slide 4)
  //////////////////////////////////////////////////////////////////////////////

  // Power-on reset and signal initialization
  task automatic Initialize();
    begin
      clk          = 1'b0;
      RST_n        = 1'b0;
      send_cmd     = 1'b0;
      cmd          = 16'h0000;
      batt         = 12'hD80;  // nominal battery voltage
      clr_resp_rdy = 1'b0;
      @(negedge clk);
      @(negedge clk);
      RST_n = 1'b1;
      @(negedge clk);
    end
  endtask

  // Push a 16-bit command through RemoteComm and wait until both UART
  // bytes have been transmitted (cmd_sent asserted).
  task automatic SendCmd(input [15:0] c);
    begin
      @(negedge clk);
      cmd      = c;
      send_cmd = 1'b1;
      @(negedge clk);
      send_cmd = 1'b0;
      @(posedge cmd_sent);
      @(negedge clk);
    end
  endtask

  // Wait up to max_cycles for a positive-ack (resp_rdy rising with resp==0xA5),
  // then clear resp_rdy via clr_resp_rdy so the next ack is a clean posedge.
  task automatic ChkPosAck(input int max_cycles, input string label);
    int cyc;
    bit got;
    begin
      got = 1'b0;
      cyc = 0;
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
        $error("[%0t] %s: ChkPosAck TIMEOUT after %0d cycles (no resp_rdy)",
               $time, label, max_cycles);
        $stop();
      end
      if (resp !== 8'hA5) begin
        $error("[%0t] %s: ChkPosAck BAD RESP: expected 0xA5, got 0x%02h",
               $time, label, resp);
        $stop();
      end
      $display("[%0t] %s: positive ack (0xA5) received", $time, label);

      // Release resp_rdy so the next DUT response will produce a new posedge.
      @(negedge clk);
      clr_resp_rdy = 1'b1;
      @(negedge clk);
      clr_resp_rdy = 1'b0;
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////
  // Helpers used by the affinity / algorithm tests
  //////////////////////////////////////////////////////////////////////////////

  // Force the three maze_solve inputs that decide MOVE->SOL_CHECK and the
  // turn direction.  Forcing the input ports of iSLV overrides whatever
  // sensor_intf/navigate are driving so we can exercise the algorithm in a
  // controlled way without moving the robot to specific maze cells.
  task automatic ForceMazeInputs(input logic lft, input logic rght, input logic cmplt);
    begin
      force_lft_opn  = lft;
      force_rght_opn = rght;
      force_mv_cmplt = cmplt;
      force iDUT.iSLV.lft_opn  = force_lft_opn;
      force iDUT.iSLV.rght_opn = force_rght_opn;
      force iDUT.iSLV.mv_cmplt = force_mv_cmplt;
    end
  endtask

  // Drop every previously-applied force on maze_solve inputs.
  task automatic ReleaseMazeInputs();
    begin
      release iDUT.iSLV.lft_opn;
      release iDUT.iSLV.rght_opn;
      release iDUT.iSLV.mv_cmplt;
    end
  endtask

  // Wait (with timeout) for cmd_md to fall low.  cmd_proc holds cmd_md high
  // while in command mode and drops it once a maze-solve opcode is latched;
  // that is the exact moment maze_solve is allowed to leave IDLE.
  task automatic WaitForCmdMdLow(input int max_cycles, input string label);
    int cyc;
    begin
      cyc = 0;
      while (iDUT.cmd_md === 1'b1 && cyc < max_cycles) begin
        @(posedge clk);
        cyc++;
      end
      if (iDUT.cmd_md === 1'b1) begin
        $error("[%0t] %s: cmd_md never dropped after maze-solve cmd (%0d cyc)",
               $time, label, max_cycles);
        $stop();
      end
      $display("[%0t] %s: cmd_md is low (maze_solve mode active)", $time, label);
    end
  endtask

  // Wait (with timeout) until the maze_solve FSM is parked in a given state.
  task automatic WaitForState(input logic [1:0] tgt, input int max_cycles, input string label);
    int cyc;
    begin
      cyc = 0;
      while (iDUT.iSLV.state !== tgt && cyc < max_cycles) begin
        @(posedge clk);
        cyc++;
      end
      if (iDUT.iSLV.state !== tgt) begin
        $error("[%0t] %s: timeout waiting for state==%0d (cur=%0d)",
               $time, label, tgt, iDUT.iSLV.state);
        $stop();
      end
    end
  endtask

  // Wait (with timeout) until the piezo_drv FSM (instance ICHRG) is in a
  // given state.  Used by STEP 6 to walk through every note of the "Charge!"
  // fanfare; the timeout must be generous because each beat consumes
  // hundreds of thousands of clocks even at FAST_SIM=1.
  task automatic WaitForPiezoState(input logic [2:0] tgt, input int max_cycles,
                                    input string label);
    int cyc;
    begin
      cyc = 0;
      while (iDUT.ICHRG.state !== tgt && cyc < max_cycles) begin
        @(posedge clk);
        cyc++;
      end
      if (iDUT.ICHRG.state !== tgt) begin
        $error("[%0t] %s: timeout waiting for piezo state==%0d (cur=%0d)",
               $time, label, tgt, iDUT.ICHRG.state);
        $stop();
      end
      $display("[%0t] %s: piezo reached state %0d", $time, label, tgt);
    end
  endtask

  // Run one left-affinity turn scenario:
  //   - Forces (lft, rght, cmplt) so MOVE -> SOL_CHECK fires on the next clk.
  //   - Captures dsrd_hdng before the SOL_CHECK pulse.
  //   - Waits for the single-cycle strt_hdng pulse (= we're in SOL_CHECK).
  //   - Waits one more clock so dsrd_hdng latches dsrd_hdng_tmp, then checks
  //     that dsrd_hdng moved by exactly the expected delta.
  //   - Parks inputs back to all-zero so the FSM stays in MOVE for the next
  //     scenario.
  task automatic ChkTurnCase(input logic lft, input logic rght, input logic cmplt,
                             input logic [11:0] delta, input string label);
    logic [11:0] prev_hdng;
    logic [11:0] expect_hdng;
    int cyc;
    begin
      // Make sure the FSM is in MOVE before injecting the scenario.
      WaitForState(MOVE_S, 1000, {label, " (pre-MOVE wait)"});

      // Snapshot dsrd_hdng before the turn we're about to provoke.
      prev_hdng = iDUT.iSLV.dsrd_hdng;

      // Apply scenario inputs.  In left-affinity mode (cmd0=1) the MOVE->
      // SOL_CHECK transition condition is (lft_opn | mv_cmplt), so any of the
      // three scenarios below will fire on the next clk edge.
      ForceMazeInputs(lft, rght, cmplt);

      // Wait for strt_hdng to assert (pulses for exactly one cycle, in
      // SOL_CHECK).  In SOL_CHECK, dsrd_hdng_tmp is computed combinationally
      // from the currently-forced lft_opn / rght_opn.
      cyc = 0;
      while (iDUT.iSLV.strt_hdng !== 1'b1 && cyc < 1000) begin
        @(posedge clk);
        cyc++;
      end
      if (iDUT.iSLV.strt_hdng !== 1'b1) begin
        $error("[%0t] %s: timeout waiting for strt_hdng (FSM stuck out of SOL_CHECK)",
               $time, label);
        $stop();
      end

      // dsrd_hdng latches dsrd_hdng_tmp on the *next* posedge clk while
      // strt_hdng is still high.  Wait that edge, then settle to observe the
      // updated NBA value.
      @(posedge clk);
      #1;

      // Compute and check the expected post-turn heading.  All deltas wrap
      // naturally inside 12 bits (-0x400 == +0xC00 in 12-bit modular arith).
      expect_hdng = prev_hdng + delta;
      if (iDUT.iSLV.dsrd_hdng !== expect_hdng) begin
        $error("[%0t] %s FAIL: dsrd_hdng 0x%03h -> 0x%03h, expected 0x%03h (delta 0x%03h)",
               $time, label, prev_hdng, iDUT.iSLV.dsrd_hdng, expect_hdng, delta);
        $stop();
      end
      $display("[%0t] %s OK: dsrd_hdng 0x%03h -> 0x%03h (delta 0x%03h)",
               $time, label, prev_hdng, iDUT.iSLV.dsrd_hdng, delta);

      // Park inputs neutral so the FSM falls back to MOVE and stays there
      // until the next scenario.
      ForceMazeInputs(1'b0, 1'b0, 1'b0);
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////
  // Global simulation timeout (safety net)
  //////////////////////////////////////////////////////////////////////////////
  initial begin : global_timeout
    // Raised from 30 ms to 100 ms because STEP 6 has to let the piezo
    // "Charge!" fanfare (~3.6 M sim cycles at FAST_SIM=1) run to completion.
    #100_000_000;
    $error("GLOBAL SIM TIMEOUT reached without completion");
    $stop();
  end

  //////////////////////////////////////////////////////////////////////////////
  // Main test sequence: calibration + left-affinity algorithm checks
  //////////////////////////////////////////////////////////////////////////////
  initial begin
    Initialize();

    ///////////////////////////////////////////////////////////////////////////
    // STEP 1: calibration sanity (gyro calibrate => 0xA5).  Same check as
    // before -- nothing else can be trusted until cal_done has fired.
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 1: sending calibrate (0x0000)", $time);
    SendCmd(16'h0000);
    ChkPosAck(2_000_000, "CAL");

    ///////////////////////////////////////////////////////////////////////////
    // STEP 2: send maze-solve LEFT-affinity command (opcode 3'b011, cmd[0]=1
    // => 0x6001).  Immediately neutralize the maze_solve open/cmplt inputs
    // so that, when the FSM transitions IDLE -> MOVE, it sees no openings
    // and no move-complete and parks in MOVE (does not race off into
    // SOL_CHECK on whatever sensor_intf was reporting from the start cell).
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 2: sending maze-solve LEFT-affinity (0x6001)", $time);
    SendCmd(16'h6001);
    ForceMazeInputs(1'b0, 1'b0, 1'b0);

    // Wait for cmd_md to drop -- this is the moment maze_solve is allowed
    // to leave IDLE and start its own MOVE/SOL_CHECK flow.
    WaitForCmdMdLow(500_000, "STEP 2");

    ///////////////////////////////////////////////////////////////////////////
    // STEP 3: cmd[0] selects left affinity.
    //
    // In maze_solve.sv:
    //   assign stp_lft  = cmd0;
    //   assign stp_rght = ~cmd0;
    //
    // For cmd[0]=1 (left affinity) we therefore expect:
    //   * iDUT.iSLV.cmd0     == 1
    //   * iDUT.iSLV.stp_lft  == 1
    //   * iDUT.iSLV.stp_rght == 0
    //
    // The muxed top-level iDUT.stp_lft/stp_rght are
    //   stp_lft  = cmd_md ? stp_lft_cmd  : stp_lft_slv
    //   stp_rght = cmd_md ? stp_rght_cmd : stp_rght_slv
    // and since cmd_md is now low, they should also reflect the solver's
    // 1/0 values.
    ///////////////////////////////////////////////////////////////////////////
    @(negedge clk);
    $display("[%0t] STEP 3: checking left-affinity selection from cmd[0]", $time);

    // (a) maze_solve sees cmd0=1 (latched cmd[0] coming through cmd_proc).
    if (iDUT.iSLV.cmd0 !== 1'b1) begin
      $error("[%0t] STEP 3 FAIL: maze_solve cmd0=%b (expected 1 for left affinity)",
             $time, iDUT.iSLV.cmd0);
      $stop();
    end

    // (b) maze_solve drives stp_lft=1, stp_rght=0 (left-affinity = ignore left
    //     opening when stopping... matches stp_lft = cmd0).
    if (iDUT.iSLV.stp_lft !== 1'b1 || iDUT.iSLV.stp_rght !== 1'b0) begin
      $error("[%0t] STEP 3 FAIL: iSLV.stp_lft=%b iSLV.stp_rght=%b (expected 1,0)",
             $time, iDUT.iSLV.stp_lft, iDUT.iSLV.stp_rght);
      $stop();
    end

    // (c) The muxed top-level stp_lft/stp_rght must now select the solver
    //     side (because cmd_md is low) and therefore also report 1,0.
    if (iDUT.stp_lft !== 1'b1 || iDUT.stp_rght !== 1'b0) begin
      $error("[%0t] STEP 3 FAIL: top stp_lft=%b stp_rght=%b (expected 1,0; cmd_md=%b)",
             $time, iDUT.stp_lft, iDUT.stp_rght, iDUT.cmd_md);
      $stop();
    end
    $display("[%0t] STEP 3 OK: left affinity selected (cmd0=1, stp_lft=1, stp_rght=0)",
             $time);

    ///////////////////////////////////////////////////////////////////////////
    // STEP 4: forward motion when no wall.
    //
    // maze_solve fires strt_mv on the IDLE->MOVE transition (which we expect
    // to have already happened when cmd_md dropped), and stays in MOVE so
    // long as none of (lft_opn & cmd0), (rght_opn & ~cmd0), mv_cmplt are
    // true.  Our forces hold all three open/cmplt inputs at 0, so the FSM
    // must remain in MOVE and the seen_strt_mv latch must already be set.
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 4: checking forward-motion behavior in MOVE", $time);

    // (a) strt_mv was pulsed at least once (kicked navigate into moving).
    if (!seen_strt_mv) begin
      $error("[%0t] STEP 4 FAIL: maze_solve never pulsed strt_mv after IDLE->MOVE",
             $time);
      $stop();
    end

    // (b) The FSM is in MOVE right now (no openings, no mv_cmplt -> stay).
    WaitForState(MOVE_S, 1000, "STEP 4 (enter MOVE)");

    // (c) With inputs forced quiet, the FSM must stay in MOVE for many
    //     cycles -- "we keep going forward as long as there is no wall".
    repeat (200) begin
      @(posedge clk);
      if (iDUT.iSLV.state !== MOVE_S) begin
        $error("[%0t] STEP 4 FAIL: FSM left MOVE (state=%0d) with no openings/cmplt",
               $time, iDUT.iSLV.state);
        $stop();
      end
    end
    $display("[%0t] STEP 4 OK: FSM stayed in MOVE for 200 cycles (forward motion held)",
             $time);

    ///////////////////////////////////////////////////////////////////////////
    // STEP 5: left-affinity algorithm, three independent turn cases.
    //
    // Recall the SOL_CHECK arm for cmd0=1:
    //     if (lft_opn)        dsrd_hdng_tmp = dsrd_hdng + 12'h400;  // left
    //     else if (rght_opn)  dsrd_hdng_tmp = dsrd_hdng - 12'h400;  // right
    //     else                dsrd_hdng_tmp = dsrd_hdng + 12'h800;  // 180
    //
    // Case (a): a left opening exists -- the FSM must always prefer it.
    //           lft=1 alone is enough to trigger MOVE -> SOL_CHECK because
    //           in left affinity the MOVE exit cond is (lft_opn | mv_cmplt).
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 5a: left opening -> +0x400 (turn left)", $time);
    ChkTurnCase(.lft(1'b1), .rght(1'b0), .cmplt(1'b0),
                .delta(12'h400), .label("STEP 5a LEFT-TURN"));

    ///////////////////////////////////////////////////////////////////////////
    // Case (b): no left opening, right opening present, move-complete fires
    //           (we hit a wall in front so navigate signaled mv_cmplt).
    //           The left-affinity priority then falls through to the right
    //           branch -- expect dsrd_hdng -= 0x400.
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 5b: no left, right open + mv_cmplt -> -0x400 (turn right)", $time);
    ChkTurnCase(.lft(1'b0), .rght(1'b1), .cmplt(1'b1),
                .delta(12'hC00),  // -0x400 mod 0x1000
                .label("STEP 5b RIGHT-TURN"));

    ///////////////////////////////////////////////////////////////////////////
    // Case (c): dead end -- no openings on either side and mv_cmplt fires.
    //           The else branch wins: expect a 180-degree turn (+0x800).
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 5c: dead end + mv_cmplt -> +0x800 (turn 180)", $time);
    ChkTurnCase(.lft(1'b0), .rght(1'b0), .cmplt(1'b1),
                .delta(12'h800), .label("STEP 5c 180-TURN"));

    ///////////////////////////////////////////////////////////////////////////
    // STEP 6: magnet found -> fanfare + DONE + 0xA5 ack.
    //
    // In MazeRunner.sv the hall-effect sensor is wired as:
    //     assign sol_cmplt = ~hall_n;
    //
    // and sol_cmplt fans out to three consumers:
    //     - iSLV  : maze_solve sees sol_cmplt as the "puzzle solved" bit.
    //               In SOL_CHECK it is checked FIRST, so sol_cmplt=1
    //               forces the FSM to the DONE state (which is a trap
    //               state -- no more turns, no more strt_mv).
    //     - iCMD  : cmd_proc's SOLVE state pulses send_resp on sol_cmplt,
    //               which asks UART_wrapper to transmit 0xA5 back to the
    //               host.  That is the final positive ack for the run.
    //     - ICHRG : piezo_drv takes sol_cmplt as its 'fanfare' input.  On
    //               the rising edge it leaves IDLE and walks the full
    //               "Charge!" sequence:
    //                 IDLE -> G6_M -> C7_M -> E7_M -> G7_M_L -> E7_L -> G7_H -> IDLE
    //               The E7_M exit is the critical disambiguator:
    //                 if (batt_low)         -> IDLE   (low-battery beep: 3 notes)
    //                 else if (fanfare)     -> G7_M_L (magnet fanfare : 6 notes)
    //                 else                  -> IDLE
    //               So reaching G7_H PROVES the magnet-found path was taken,
    //               not a low-battery alarm.
    //
    // How we drive this deterministically from the TB:
    //   (1) Pin `iDUT.batt_low` to 0.  sensor_intf asserts batt_low when
    //       vbatt[11:4] < 0xD9 and our nominal batt=0xD80 sits just below
    //       that threshold, which would otherwise let piezo_drv loop on
    //       the low-battery beep and mask the fanfare path.
    //   (2) Wait for piezo_drv to settle in IDLE so the walk starts from a
    //       known state.
    //   (3) Force `iDUT.sol_cmplt = 1` -- this overrides the assign above
    //       and makes every consumer see the magnet as found.
    //   (4) Provoke the maze_solve MOVE->SOL_CHECK transition by asserting
    //       mv_cmplt via ForceMazeInputs(0,0,1); once in SOL_CHECK the
    //       sol_cmplt arm wins and the FSM drops into DONE.
    //   (5) Check, in order:
    //         a) piezo_drv has entered G6_M (fanfare actually started),
    //         b) cmd_proc has transmitted the final 0xA5 positive ack,
    //         c) maze_solve has reached DONE,
    //         d) piezo_drv walks through C7_M, E7_M, G7_M_L, E7_L, G7_H,
    //            and then returns to IDLE (full fanfare played, not cut
    //            short by a batt_low alarm), and
    //         e) maze_solve is still parked in DONE at the very end.
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 6: magnet-found fanfare + DONE + ack", $time);

    // (1) Keep low-battery detection from triggering piezo_drv.  If we
    // did not force this low, sensor_intf would be asserting batt_low
    // continuously with batt=0xD80 and piezo_drv would be in a loop of
    // 3-note alarm beeps; any "leftover" beep would also truncate the
    // fanfare at E7_M (see the E7_M arm of piezo_drv.sv).
    force iDUT.batt_low = 1'b0;

    // (2) Wait for the piezo FSM to settle in IDLE.  If a batt_low beep
    // was in flight before (1) forced batt_low low, the FSM will finish
    // whatever note it was playing and then -- with both batt_low and
    // fanfare at 0 -- park itself back in IDLE.
    WaitForPiezoState(PIEZO_IDLE_S, 2_000_000, "STEP 6 (piezo IDLE pre-check)");

    // (3) Magnet found.  Overriding the MazeRunner-level wire propagates
    // through all three consumers' input ports simultaneously.
    force iDUT.sol_cmplt = 1'b1;

    // (4) Provoke MOVE -> SOL_CHECK so maze_solve can actually observe
    // sol_cmplt.  With (lft_opn, rght_opn, mv_cmplt) = (0,0,1) and cmd0=1
    // the MOVE exit cond (lft_opn | mv_cmplt) is true on the next clk.
    // sol_cmplt then wins in SOL_CHECK and we go straight to DONE.
    ForceMazeInputs(1'b0, 1'b0, 1'b1);

    // (5a) piezo_drv must leave IDLE on the next clock and land in G6_M;
    // failing this would mean fanfare never reached the piezo_drv input.
    WaitForPiezoState(PIEZO_G6_M_S, 1_000, "STEP 6 PIEZO G6_M (fanfare start)");

    // (5b) cmd_proc's SOLVE arm pulses send_resp on sol_cmplt; 0xA5 should
    // come back through UART_wrapper + RemoteComm within a small fraction
    // of the first piezo beat (each beat is ~524 k cycles).
    ChkPosAck(2_000_000, "STEP 6 SOLVE");

    // (5c) By this point maze_solve should have transitioned SOL_CHECK ->
    // DONE.  Check with a short timeout -- if anything was wrong with the
    // sol_cmplt wiring iSLV would still be stuck in MOVE/SOL_CHECK.
    WaitForState(DONE_S, 1_000, "STEP 6 MAZE_SOLVE DONE");

    // (5d) Finish walking the fanfare.  Each WaitForPiezoState is bounded
    // by ~2 M cycles which easily covers the longest (G7_H, H_init beat
    // ~= 1.05 M cycles) at FAST_SIM=1.
    WaitForPiezoState(PIEZO_C7_M_S,   2_000_000, "STEP 6 PIEZO C7_M");
    WaitForPiezoState(PIEZO_E7_M_S,   2_000_000, "STEP 6 PIEZO E7_M");
    WaitForPiezoState(PIEZO_G7_M_L_S, 2_000_000, "STEP 6 PIEZO G7_M_L (fanfare-only)");
    WaitForPiezoState(PIEZO_E7_L_S,   2_000_000, "STEP 6 PIEZO E7_L");
    WaitForPiezoState(PIEZO_G7_H_S,   1_000_000, "STEP 6 PIEZO G7_H (proof of fanfare)");
    WaitForPiezoState(PIEZO_IDLE_S,   2_000_000, "STEP 6 PIEZO IDLE (fanfare done)");

    // (5e) DONE is a trap state; the FSM must not have wandered off.
    if (iDUT.iSLV.state !== DONE_S) begin
      $error("[%0t] STEP 6 FAIL: maze_solve left DONE (state=%0d)",
             $time, iDUT.iSLV.state);
      $stop();
    end
    $display("[%0t] STEP 6 OK: magnet -> full Charge! fanfare, DONE, and 0xA5 ack",
             $time);

    ///////////////////////////////////////////////////////////////////////////
    // Wrap-up: drop all forces so the rest of the design can run normally
    // (only matters if more checks are added after this).
    ///////////////////////////////////////////////////////////////////////////
    release iDUT.sol_cmplt;
    release iDUT.batt_low;
    ReleaseMazeInputs();

    $display("[%0t] LEFT AFFINITY (calibration + algorithm + magnet) TEST PASSED",
             $time);
    disable global_timeout;
    $stop();
  end

  //////////////////////////////////////////////////////////////////////////////
  // Clock: 10 ns period (100 MHz sim clock).  The spec notes 50 MHz is for
  // the FPGA-mapped version; in simulation we run faster and rely on
  // FAST_SIM=1 inside MazeRunner to keep the run short.
  //////////////////////////////////////////////////////////////////////////////
  always
    #5 clk = ~clk;

endmodule
