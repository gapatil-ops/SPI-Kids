/**
 * Testbench for MazeRunner module - this testbench does a manual solve of the maze, sending commands to the MazeRunner robot
 */
module MazeRunner_tb();
  
  reg clk,RST_n;
  reg snd_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xD80 is nominal
  
  logic cmd_sent;				
  logic resp_rdy, clr_resp_rdy;				// MazeRunner has sent a pos acknowledge
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
  wire [7:0] LED;

  ///// Internal registers for testing purposes??? /////////
  
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.INRT_SS_n(INRT_SS_n),.INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI),.INRT_MISO(INRT_MISO),.INRT_INT(INRT_INT),
				  .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
				  .A2D_MISO(A2D_MISO),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
				  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.RX(RX_TX),.TX(TX_RX),
				  .hall_n(hall_n),.piezo(piezo),.piezo_n(),.IR_lft_en(IR_lft_en),
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED(LED));
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .snd_cmd(snd_cmd),
               .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp), .clr_resp_rdy(clr_resp_rdy));
			   
  ///////////////////////////////////////////////////
  // Instantiate physical model of robot and maze //
  /////////////////////////////////////////////////
  RunnerPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(INRT_SS_n),.SCLK(INRT_SCLK),.MISO(INRT_MISO),
                      .MOSI(INRT_MOSI),.INT(INRT_INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),
                     .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),.IR_rght_en(IR_rght_en),
					 .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					 .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));

  // COMMANDS
  localparam logic [15:0] CALIBRATE = 16'h0000,
                          HEADING_BASE = 16'h2000,
                          MOVE_BASE = 16'h4000,
                          SOLVE_BASE = 16'h6000;
  // DIRECTIONS
  localparam logic [11:0] NORTH = 12'h000,
                          WEST = 12'h3FF,
                          SOUTH = 12'h7FF,
                          EAST = 12'hC00;
  // MOVE STOP CONDITIONS
  localparam logic [1:0] STP_RGHT = 2'b01,
                         STP_LFT = 2'b10;
  //  SOLVE AFFINITY CONDITIONS
  localparam logic LFT_AFFN = 1'b1,
                   RGHT_AFFN = 1'b0;

  /* Helper task to initialize and reset the testbench */
  task initialize_and_reset;
    // initialize all signals to default values
    clk = 1'b0;
    RST_n = 1'b0;
    snd_cmd = 1'b0;
    cmd = 16'h0000;
    batt = 12'hDA0; // nominal battery voltage
    @(posedge clk);
    @(negedge clk);
    RST_n = 1'b1; // release reset
    clr_resp_rdy = 1'b0; // make sure response ready flag is low at the beginning of the test
  endtask

  /* Helper task to send a command */
  task send_command(input logic [15:0] cmd_to_send);
    @(negedge clk);
    cmd = cmd_to_send;
    snd_cmd = 1'b1; // pulse send command
    @(negedge clk);
    snd_cmd = 1'b0;
  endtask

  task check_for_ack;
    fork
      begin: wait_for_ack // We wait for an acknowledgement from the robot
        wait(resp_rdy);
        disable ack_time_out; // If we get an acknowledge, we disable our timeout
        if (resp !== 8'hA5) begin
          $display("Expected 8'hA5 as response, but got %h", resp);
          $stop();
        end else begin
          @(negedge clk);
          clr_resp_rdy = 1'b1; // Clear the response ready flag for the next command
          @(negedge clk);
          clr_resp_rdy = 1'b0;
        end
      end

      begin: ack_time_out
        repeat (71000) @(negedge clk);
        $display("Did not get an acknowledge from the robot from CALIBRATION command");
        $stop();
      end
    join
  endtask

  initial begin

    /// Your magic goes here ///
    initialize_and_reset();

    // Send a calibration command and wait for it complete before sending any other commands.
    send_command(CALIBRATE);
    
    // TEST 1: Calibration Command Test
    fork
      
      begin: cal_done_timeout
        wait(iDUT.strt_cal);
        repeat (100_000) @(negedge clk);
        $display("Calibration did not complete in expected time");
      end

      begin: int_cal_timeout
        repeat (54000) @(negedge clk);
        $display("Internal start cal signal was never asserted");
        $stop();
      end

      begin: check_internal_cal // Checking the internal calibration signals
        
        wait(iDUT.strt_cal);
        disable int_cal_timeout;

        assert property ( @(negedge clk) iDUT.strt_cal |-> ##1 LED[0] ) 
        else begin // LED[0] is the in_cal signal
          $display("strt_cal was asserted but in_cal was not asserted on the next cycle");
          $stop();
        end

        //enable cal_done_timeout; // If calibration starts, we enable the timeout for calibration to complete
        wait(iDUT.cal_done);
        disable cal_done_timeout;
      end

    join

    check_for_ack(); // We wait for an acknowledgement from the robot after the calibration command completes
    $display(); // Add a blank line for readability between tests

    // TEST 2: Head south

    send_command(HEADING_BASE + SOUTH);

    fork
      begin: int_heading_timeout
        repeat (54000) @(negedge clk);
        $display("Internal heading command was never acknowledged");
        $stop();
      end

      begin: heading_done_timeout
        wait(iDUT.strt_hdng);
        repeat (10_000_000) @(negedge clk);
        $display("Heading change did not complete in expected time");
        $stop();
      end

      begin: check_internal_heading // Checking the internal heading signals
        wait(iDUT.strt_hdng);
        disable int_heading_timeout;
        while (!iDUT.mv_cmplt) @(negedge clk);
        disable heading_done_timeout;
      end
      
    join

    $display("Current heading according to inertial unit is %h", iDUT.actl_hdng);
    $display("Current heading according to iPHYS is %h", iPHYS.heading_robot[19:8]);
    $display("Current position is (%0d, %0d)", iPHYS.xx[14:8], iPHYS.yy[14:8]);
    $display("Expected position is still (56,56) since we haven't moved yet and that's where we start in the maze");
    $display("Expected heading is %h", SOUTH);

    if (!(iDUT.actl_hdng inside {[SOUTH-8'h50:SOUTH+8'h50]})) begin
      $display("Expected actual heading to be around %h but got %h", SOUTH, iDUT.actl_hdng);
      $stop();
    end

    if (!(iPHYS.heading_robot[19:8] inside {[SOUTH-8'h50:SOUTH+8'h50]})) begin
      $display("Expected physics heading to be around %h but got %h", SOUTH, iPHYS.heading_robot[19:8]);
      $stop();
    end

    $display(); // Add a blank line for readability between tests
    check_for_ack(); // We wait for an acknowledgement from the robot after the heading command completes
    

    // TEST 3: Move forward until we see an open on the right, then stop

    send_command(MOVE_BASE + STP_RGHT);

    fork
      begin: move_start_timeout
        repeat (54000) @(negedge clk);
        $display("Internal move command was never acknowledged");
        $stop();
      end

      begin: move_done_timeout
        wait(iDUT.strt_mv);
        repeat (10_000_000) @(negedge clk);
        $display("Move did not complete in expected time");
        $stop();
      end

      begin: check_internal_move // Checking the internal move signals
        wait(iDUT.strt_mv);
        disable move_start_timeout;
        while (!iDUT.mv_cmplt) @(negedge clk);
        disable move_done_timeout;
      end
    join

    $display("Current position according to iPHYS is (%0d, %0d)", iPHYS.xx[14:8], iPHYS.yy[14:8]);
    $display("Expected position is around (56,40) since we should just have moved south 1 box");
    $display("Current heading according to inertial unit is %h", iDUT.actl_hdng);
    $display("Current heading according to iPHYS is %h", iPHYS.heading_robot[19:8]);
    $display("Expected heading is still %h", SOUTH);

    // The boxes of the maze are 16 units wide, so we want our bot's center position to be within 4 units of (56,40) in either direction

    if (!(iPHYS.xx[14:8] inside {[56-4:56+4]})) begin
      $display("Expected x position to be around %d but got %d", 56, iPHYS.xx[14:8]);
      $stop();
    end

    if (!(iPHYS.yy[14:8] inside {[40-4:40+4]})) begin
      $display("Expected y position to be around %d but got %d", 40, iPHYS.yy[14:8]);
      $stop();
    end

    check_for_ack(); // We wait for an acknowledgement from the robot after the move command completes
    $display(); // Add a blank line for readability between tests

    // TEST 4: Head west

    send_command(HEADING_BASE + WEST);

    fork
      begin: heading_start_timeout_2
        repeat (54000) @(negedge clk);
        $display("Internal heading command was never acknowledged");
        $stop();
      end

      begin: heading_done_timeout_2
        wait(iDUT.strt_hdng);
        repeat (10_000_000) @(negedge clk);
        $display("Heading change did not complete in expected time");
        $stop();
      end

      begin: check_internal_heading_2 // Checking the internal heading signals
        wait(iDUT.strt_hdng);
        disable heading_start_timeout_2;
        while (!iDUT.mv_cmplt) @(negedge clk);
        disable heading_done_timeout_2;
      end
      
    join

    $display("Current heading according to inertial unit is %h", iDUT.actl_hdng);
    $display("Current heading according to iPHYS is %h", iPHYS.heading_robot[19:8]);
    $display("Current position is (%0d, %0d)", iPHYS.xx[14:8], iPHYS.yy[14:8]);
    $display("Expected position is still (56,40)");
    $display("Expected heading is %h", WEST);

    if (!(iDUT.actl_hdng inside {[WEST-8'h50:WEST+8'h50]})) begin
      $display("Expected actual heading to be around %h but got %h", WEST, iDUT.actl_hdng);
      $stop();
    end

    if (!(iPHYS.heading_robot[19:8] inside {[WEST-8'h50:WEST+8'h50]})) begin
      $display("Expected physics heading to be around %h but got %h", WEST, iPHYS.heading_robot[19:8]);
      $stop();
    end

    check_for_ack(); // We wait for an acknowledgement from the robot after the heading command completes
    $display(); // Add a blank line for readability between tests

    // TEST 5: Move forward until we see an open on the left, then stop

    send_command(MOVE_BASE + STP_LFT);

    fork
      begin: move_start_timeout_2
        repeat (54000) @(negedge clk);
        $display("Internal move command was never acknowledged");
        $stop();
      end

      begin: move_done_timeout_2
        wait(iDUT.strt_mv);
        repeat (10_000_000) @(negedge clk);
        $display("Move did not complete in expected time");
        $stop();
      end

      begin: check_internal_move_2 // Checking the internal move signals
        wait(iDUT.strt_mv);
        disable move_start_timeout_2;
        while (!iDUT.mv_cmplt) @(negedge clk);
        disable move_done_timeout_2;
      end
    join

    $display("Current position according to iPHYS is (%0d, %0d)", iPHYS.xx[14:8], iPHYS.yy[14:8]);
    $display("Expected position is around (24,40) since we should just have moved west 2 boxes");
    $display("Current heading according to inertial unit is %h", iDUT.actl_hdng);
    $display("Current heading according to iPHYS is %h", iPHYS.heading_robot[19:8]);
    $display("Expected heading is still %h", WEST);

    // The boxes of the maze are 16 units wide, so we want our bot's center position to be within 4 units of (24,40) in either direction

    if (!(iPHYS.xx[14:8] inside {[24-4:24+4]})) begin
      $display("Expected x position to be around %d but got %d", 24, iPHYS.xx[14:8]);
      $stop();
    end

    if (!(iPHYS.yy[14:8] inside {[40-4:40+4]})) begin
      $display("Expected y position to be around %d but got %d", 40, iPHYS.yy[14:8]);
      $stop();
    end

    check_for_ack(); // We wait for an acknowledgement from the robot after the move command completes
    $display(); // Add a blank line for readability between tests

    // TEST 6: Now, the position we're at is actually the position of the magnet, so let's check if the robot detects
    // it and we get a solution complete acknowledgement after this

    if (iDUT.sol_cmplt !== 1'b1) begin
      $display("Expected sol_cmplt to be 1 since we should be on the magnet, but got %b", iDUT.sol_cmplt);
      $stop();
    end

    // TEST 7: We're now going to let fanfare play, check out the PWM wave and see if you can guess the song :)

    #37_000_000; // Let the fanfare play for a bit

    $display("All tests passed!!");
    $stop();
	
  end


  
  always
    #5 clk = ~clk;
	
endmodule
