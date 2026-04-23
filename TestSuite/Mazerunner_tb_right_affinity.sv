module MazeRunner_tb_right_affinity();
  
  reg clk,RST_n;
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xD80 is nominal
  
  logic cmd_sent;				
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  
  /////////////////////////////////////////////////////////////////////////
  // Signals interconnecting MazeRunner to RunnerPhysics and RemoteComm //
  ///////////////////////////////////////////////////////////////////////
  wire TX_RX,RX_TX;
  wire INRT_SS_n,INRT_SCLK,INRT_MOSI,INRT_MISO,INRT_INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;
  wire IR_lft_en,IR_cntr_en,IR_rght_en;  
  wire piezo;

  ///// Internal registers for the right-affinity self-check /////
  logic [11:0] prev_hdng;
  logic        check_pending;
  logic        saw_lft_opn, saw_rght_opn;
  logic        arm_checker;
  int          turn_count;

  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.INRT_SS_n(INRT_SS_n),.INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI),.INRT_MISO(INRT_MISO),.INRT_INT(INRT_INT),
				  .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
				  .A2D_MISO(A2D_MISO),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
				  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.RX(RX_TX),.TX(TX_RX),
				  .hall_n(hall_n),.piezo(piezo),.piezo_n(),.IR_lft_en(IR_lft_en),
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED());
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .snd_cmd(send_cmd),
               .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
			   
  ///////////////////////////////////////////////////
  // Instantiate physical model of robot and maze //
  /////////////////////////////////////////////////
  RunnerPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(INRT_SS_n),.SCLK(INRT_SCLK),.MISO(INRT_MISO),
                      .MOSI(INRT_MOSI),.INT(INRT_INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),
                     .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),.IR_rght_en(IR_rght_en),
					 .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					 .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));


  //////////////////////////////////////////////////////////////
  // Tasks: readable stimulus helpers (per project PDF slide 4) //
  //////////////////////////////////////////////////////////////
  task automatic Initialize();
    begin
      clk       = 1'b0;
      RST_n     = 1'b0;
      send_cmd  = 1'b0;
      cmd       = 16'h0000;
      batt      = 12'hD80;   // nominal battery
      arm_checker  = 1'b0;
      turn_count   = 0;
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

  // Wait for resp_rdy with resp == 0xA5 or time out after max_cycles clocks.
  task automatic WaitPosAck(input int max_cycles);
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
        $error("WaitPosAck TIMEOUT after %0d cycles (no resp_rdy)", max_cycles);
        $stop();
      end
      if (resp !== 8'hA5) begin
        $error("WaitPosAck BAD RESP: expected 0xA5, got 0x%02h", resp);
        $stop();
      end
      $display("[%0t] Got positive ack (0xA5)", $time);
    end
  endtask


  //////////////////////////////////////////////////////////////
  // Strict right-affinity checker                            //
  // Probes iDUT.iSLV (maze_solve) hierarchically. At every   //
  // strt_hdng pulse while cmd0=0, verifies the desired       //
  // heading delta matches right-affinity priority            //
  // (per maze_solve.sv lines 71-83):                         //
  //   rght_opn -> -0x400                                     //
  //   else lft_opn -> +0x400                                 //
  //   else (dead end) -> +0x800                              //
  //                                                          //
  // Also verifies that stp_lft=0 and stp_rght=1 for this run //
  // (see maze_solve.sv lines 36-37: stp_lft=cmd0,            //
  // stp_rght=~cmd0).                                         //
  //////////////////////////////////////////////////////////////
  always_ff @(posedge clk or negedge RST_n) begin
    if (!RST_n) begin
      prev_hdng     <= 12'h000;
      saw_lft_opn   <= 1'b0;
      saw_rght_opn  <= 1'b0;
      check_pending <= 1'b0;
    end else if (arm_checker) begin
      if (iDUT.iSLV.strt_hdng && !iDUT.iSLV.cmd0) begin
        prev_hdng     <= iDUT.iSLV.dsrd_hdng;
        saw_lft_opn   <= iDUT.iSLV.lft_opn;
        saw_rght_opn  <= iDUT.iSLV.rght_opn;
        check_pending <= 1'b1;
      end else if (check_pending) begin
        check_pending <= 1'b0;
        // By this edge dsrd_hdng has been updated by maze_solve.
        turn_count <= turn_count + 1;
        if (saw_rght_opn) begin
          if (iDUT.iSLV.dsrd_hdng !== (prev_hdng - 12'h400)) begin
            $error("[%0t] RIGHT AFFINITY BROKEN: rght_opn was asserted but dsrd_hdng went 0x%03h -> 0x%03h (expected -0x400)",
                   $time, prev_hdng, iDUT.iSLV.dsrd_hdng);
            $stop();
          end else begin
            $display("[%0t] Turn #%0d: right opening -> -0x400 (0x%03h -> 0x%03h) OK",
                     $time, turn_count+1, prev_hdng, iDUT.iSLV.dsrd_hdng);
          end
        end else if (saw_lft_opn) begin
          if (iDUT.iSLV.dsrd_hdng !== (prev_hdng + 12'h400)) begin
            $error("[%0t] BAD TURN: no rght_opn, lft_opn asserted but dsrd_hdng went 0x%03h -> 0x%03h (expected +0x400)",
                   $time, prev_hdng, iDUT.iSLV.dsrd_hdng);
            $stop();
          end else begin
            $display("[%0t] Turn #%0d: no right, left opening -> +0x400 (0x%03h -> 0x%03h) OK",
                     $time, turn_count+1, prev_hdng, iDUT.iSLV.dsrd_hdng);
          end
        end else begin
          if (iDUT.iSLV.dsrd_hdng !== (prev_hdng + 12'h800)) begin
            $error("[%0t] BAD TURN: dead end but dsrd_hdng went 0x%03h -> 0x%03h (expected +0x800)",
                   $time, prev_hdng, iDUT.iSLV.dsrd_hdng);
            $stop();
          end else begin
            $display("[%0t] Turn #%0d: dead end -> +0x800 (0x%03h -> 0x%03h) OK",
                     $time, turn_count+1, prev_hdng, iDUT.iSLV.dsrd_hdng);
          end
        end
      end
    end
  end

  // Continuous sanity check: in right-affinity mode the solver must drive
  // stp_lft=0 and stp_rght=1 once cmd_md has dropped (autonomous solve).
  always @(posedge clk) begin
    if (arm_checker && !iDUT.iSLV.cmd_md) begin
      if (iDUT.iSLV.stp_lft !== 1'b0) begin
        $error("[%0t] stp_lft should be 0 in right-affinity mode, got %b",
               $time, iDUT.iSLV.stp_lft);
        $stop();
      end
      if (iDUT.iSLV.stp_rght !== 1'b1) begin
        $error("[%0t] stp_rght should be 1 in right-affinity mode, got %b",
               $time, iDUT.iSLV.stp_rght);
        $stop();
      end
    end
  end


  //////////////////////////////////////////////////////////////
  // Global simulation timeout                                //
  //////////////////////////////////////////////////////////////
  initial begin : global_timeout
    #20_000_000;
    $error("GLOBAL SIM TIMEOUT reached without completion");
    $stop();
  end


  //////////////////////////////////////////////////////////////
  // Main test sequence                                       //
  //////////////////////////////////////////////////////////////
  initial begin
    Initialize();

    // 1) Calibrate the gyro (opcode 3'b000).
    $display("[%0t] Sending calibrate (0x0000)", $time);
    SendCmd(16'h0000);
    WaitPosAck(2_000_000);

    // 2) Arm the right-affinity checker, then kick off maze-solve with right affinity.
    //    Command format per cmd_proc: opcode 3'b011 = solve, cmd[0]=0 selects right.
    arm_checker = 1'b1;
    $display("[%0t] Sending maze-solve RIGHT-affinity (0x6000)", $time);
    SendCmd(16'h6000);

    // 3) Wait for final pos ack (only sent after sol_cmplt / magnet found).
    WaitPosAck(20_000_000);

    // 4) Sanity: magnet must actually be present at ack time.
    if (hall_n !== 1'b0) begin
      $error("[%0t] Pos ack received but hall_n is not low (hall_n = %b)", $time, hall_n);
      $stop();
    end

    $display("[%0t] RIGHT AFFINITY TEST PASSED (turns observed: %0d)", $time, turn_count);
    disable global_timeout;
    $stop();
  end
  
  always
    #5 clk = ~clk;
	
endmodule
