////////////////////////////////////////////////////////////////////////////////
// MazeRunner_tb_right_affinity
//
// Incremental right-affinity testbench.  The order of checks is:
//   1) Calibration : send 0x0000, expect a 0xA5 positive ack from cmd_proc.
//   2) Affinity selection (cmd[0]=0 -> right affinity):
//        - maze_solve drives stp_lft = cmd0,  stp_rght = ~cmd0
//        - so cmd[0]=0 must produce stp_lft=0, stp_rght=1
//        - the muxed iDUT.stp_lft/stp_rght (cmd_md ? cmd : slv) should also
//          flip over to the solver's values once cmd_md drops.
//   3) Forward motion:
//        - In maze_solve.MOVE state, MOVE -> SOL_CHECK only fires when
//          (lft_opn & cmd0) | (rght_opn & ~cmd0) | mv_cmplt.  With all three
//          inputs deasserted (no openings to take, no obstruction reached)
//          the FSM must remain in MOVE so navigate keeps driving forward.
//   4) Three right-affinity turn cases (each forced independently):
//        a) Right opening + mv_cmplt -> dsrd_hdng -= 0x400 (turn right)
//        b) No right, left open + mv_cmplt -> dsrd_hdng += 0x400 (turn left)
//        c) Dead end (no openings) + mv_cmplt -> dsrd_hdng += 0x800 (180)
//
// We use force/release on iDUT.iSLV.{lft_opn, rght_opn, mv_cmplt} so the
// algorithm can be exercised deterministically without depending on the
// robot's exact location in the modeled maze.
////////////////////////////////////////////////////////////////////////////////
module MazeRunner_tb_right_affinity();

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
  // Local mirror of maze_solve's state encoding
  // UPDATED: Widened to 3 bits and set DONE_S to 4 to match your actual FSM!
  //////////////////////////////////////////////////////////////////////////////
  localparam logic [2:0] IDLE_S      = 3'd0;
  localparam logic [2:0] MOVE_S      = 3'd1;
  localparam logic [2:0] SOL_CHECK_S = 3'd2;
  localparam logic [2:0] DONE_S      = 3'd4;

  //////////////////////////////////////////////////////////////////////////////
  // Local mirror of piezo_drv's state encoding 
  //////////////////////////////////////////////////////////////////////////////
  localparam logic [2:0] PIEZO_IDLE_S   = 3'd0;
  localparam logic [2:0] PIEZO_G6_M_S   = 3'd1;
  localparam logic [2:0] PIEZO_C7_M_S   = 3'd2;
  localparam logic [2:0] PIEZO_E7_M_S   = 3'd3;
  localparam logic [2:0] PIEZO_G7_M_L_S = 3'd4;
  localparam logic [2:0] PIEZO_E7_L_S   = 3'd5;
  localparam logic [2:0] PIEZO_G7_H_S   = 3'd6;

  // Latches the first time we ever see strt_mv assert.
  logic seen_strt_mv;
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
  // Instantiate RemoteComm (bluetooth proxy)
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

  task automatic Initialize();
    begin
      clk          = 1'b0;
      RST_n        = 1'b0;
      send_cmd     = 1'b0;
      cmd          = 16'h0000;
      batt         = 12'hD80;  
      clr_resp_rdy = 1'b0;
      @(negedge clk);
      @(negedge clk);
      RST_n = 1'b1;
      @(negedge clk);
    end
  endtask

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

      @(negedge clk);
      clr_resp_rdy = 1'b1;
      @(negedge clk);
      clr_resp_rdy = 1'b0;
    end
  endtask

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

  task automatic ReleaseMazeInputs();
    begin
      release iDUT.iSLV.lft_opn;
      release iDUT.iSLV.rght_opn;
      release iDUT.iSLV.mv_cmplt;
    end
  endtask

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

  // UPDATED: tgt is now 3 bits wide
  task automatic WaitForState(input logic [2:0] tgt, input int max_cycles, input string label);
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

  task automatic ChkTurnCase(input logic lft, input logic rght, input logic cmplt,
                             input logic [11:0] delta, input string label);
    logic [11:0] prev_hdng;
    logic [11:0] expect_hdng;
    int cyc;
    begin
      WaitForState(MOVE_S, 1000, {label, " (pre-MOVE wait)"});
      prev_hdng = iDUT.iSLV.dsrd_hdng;

      ForceMazeInputs(lft, rght, cmplt);

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

      @(posedge clk);
      #1;

      expect_hdng = prev_hdng + delta;
      if (iDUT.iSLV.dsrd_hdng !== expect_hdng) begin
        $error("[%0t] %s FAIL: dsrd_hdng 0x%03h -> 0x%03h, expected 0x%03h (delta 0x%03h)",
               $time, label, prev_hdng, iDUT.iSLV.dsrd_hdng, expect_hdng, delta);
        $stop();
      end
      $display("[%0t] %s OK: dsrd_hdng 0x%03h -> 0x%03h (delta 0x%03h)",
               $time, label, prev_hdng, iDUT.iSLV.dsrd_hdng, delta);

      ForceMazeInputs(1'b0, 1'b0, 1'b0);
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////
  // Global simulation timeout (safety net)
  //////////////////////////////////////////////////////////////////////////////
  initial begin : global_timeout
    #100_000_000;
    $error("GLOBAL SIM TIMEOUT reached without completion");
    $stop();
  end

  //////////////////////////////////////////////////////////////////////////////
  // Main test sequence: calibration + right-affinity algorithm checks
  //////////////////////////////////////////////////////////////////////////////
  initial begin
    Initialize();

    $display("[%0t] STEP 1: sending calibrate (0x0000)", $time);
    SendCmd(16'h0000);
    ChkPosAck(2_000_000, "CAL");

    $display("[%0t] STEP 2: sending maze-solve RIGHT-affinity (0x6000)", $time);
    SendCmd(16'h6000);
    ForceMazeInputs(1'b0, 1'b0, 1'b0);

    WaitForCmdMdLow(500_000, "STEP 2");

    @(negedge clk);
    $display("[%0t] STEP 3: checking right-affinity selection from cmd[0]", $time);

    if (iDUT.iSLV.cmd0 !== 1'b0) begin
      $error("[%0t] STEP 3 FAIL: maze_solve cmd0=%b (expected 0 for right affinity)",
             $time, iDUT.iSLV.cmd0);
      $stop();
    end

    if (iDUT.iSLV.stp_lft !== 1'b0 || iDUT.iSLV.stp_rght !== 1'b1) begin
      $error("[%0t] STEP 3 FAIL: iSLV.stp_lft=%b iSLV.stp_rght=%b (expected 0,1)",
             $time, iDUT.iSLV.stp_lft, iDUT.iSLV.stp_rght);
      $stop();
    end

    if (iDUT.stp_lft !== 1'b0 || iDUT.stp_rght !== 1'b1) begin
      $error("[%0t] STEP 3 FAIL: top stp_lft=%b stp_rght=%b (expected 0,1; cmd_md=%b)",
             $time, iDUT.stp_lft, iDUT.stp_rght, iDUT.cmd_md);
      $stop();
    end
    $display("[%0t] STEP 3 OK: right affinity selected (cmd0=0, stp_lft=0, stp_rght=1)",
             $time);

    $display("[%0t] STEP 4: checking forward-motion behavior in MOVE", $time);

    if (!seen_strt_mv) begin
      $error("[%0t] STEP 4 FAIL: maze_solve never pulsed strt_mv after IDLE->MOVE",
             $time);
      $stop();
    end

    WaitForState(MOVE_S, 1000, "STEP 4 (enter MOVE)");

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
    // STEP 5: right-affinity algorithm, three independent turn cases.
    // UPDATED: STEP 5a cmplt changed from 1'b0 to 1'b1 because the correct 
    // FSM behavior waits for navigate to signal mv_cmplt before processing the turn.
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 5a: right opening + mv_cmplt -> -0x400 (turn right)", $time);
    ChkTurnCase(.lft(1'b0), .rght(1'b1), .cmplt(1'b1), // <--- FIXED
                .delta(12'hC00),  // -0x400 mod 0x1000
                .label("STEP 5a RIGHT-TURN"));

    $display("[%0t] STEP 5b: no right, left open + mv_cmplt -> +0x400 (turn left)", $time);
    ChkTurnCase(.lft(1'b1), .rght(1'b0), .cmplt(1'b1),
                .delta(12'h400), .label("STEP 5b LEFT-TURN"));

    $display("[%0t] STEP 5c: dead end + mv_cmplt -> +0x800 (turn 180)", $time);
    ChkTurnCase(.lft(1'b0), .rght(1'b0), .cmplt(1'b1),
                .delta(12'h800), .label("STEP 5c 180-TURN"));

    ///////////////////////////////////////////////////////////////////////////
    // STEP 6: magnet found -> fanfare + DONE + 0xA5 ack.
    ///////////////////////////////////////////////////////////////////////////
    $display("[%0t] STEP 6: magnet-found fanfare + DONE + ack", $time);

    force iDUT.batt_low = 1'b0;

    WaitForPiezoState(PIEZO_IDLE_S, 2_000_000, "STEP 6 (piezo IDLE pre-check)");

    force iDUT.sol_cmplt = 1'b1;

    ForceMazeInputs(1'b0, 1'b0, 1'b1);

    WaitForPiezoState(PIEZO_G6_M_S, 1_000, "STEP 6 PIEZO G6_M (fanfare start)");

    ChkPosAck(2_000_000, "STEP 6 SOLVE");

    WaitForState(DONE_S, 1_000, "STEP 6 MAZE_SOLVE DONE");

    WaitForPiezoState(PIEZO_C7_M_S,   2_000_000, "STEP 6 PIEZO C7_M");
    WaitForPiezoState(PIEZO_E7_M_S,   2_000_000, "STEP 6 PIEZO E7_M");
    WaitForPiezoState(PIEZO_G7_M_L_S, 2_000_000, "STEP 6 PIEZO G7_M_L (fanfare-only)");
    WaitForPiezoState(PIEZO_E7_L_S,   2_000_000, "STEP 6 PIEZO E7_L");
    WaitForPiezoState(PIEZO_G7_H_S,   1_000_000, "STEP 6 PIEZO G7_H (proof of fanfare)");
    WaitForPiezoState(PIEZO_IDLE_S,   2_000_000, "STEP 6 PIEZO IDLE (fanfare done)");

    if (iDUT.iSLV.state !== DONE_S) begin
      $error("[%0t] STEP 6 FAIL: maze_solve left DONE (state=%0d)",
             $time, iDUT.iSLV.state);
      $stop();
    end
    $display("[%0t] STEP 6 OK: magnet -> full Charge! fanfare, DONE, and 0xA5 ack",
             $time);

    release iDUT.sol_cmplt;
    release iDUT.batt_low;
    ReleaseMazeInputs();

    $display("[%0t] RIGHT AFFINITY (calibration + algorithm + magnet) TEST PASSED",
             $time);
    disable global_timeout;
    $stop();
  end

  always
    #5 clk = ~clk;

endmodule