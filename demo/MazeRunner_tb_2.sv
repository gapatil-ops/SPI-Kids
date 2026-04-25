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
    batt = 12'hD80; // nominal battery voltage
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

    // TEST 2: Head west

    send_command(HEADING_BASE + WEST);

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
    $display("Expected heading is %h", WEST);

    if (!(iDUT.actl_hdng inside {[WEST-8'h40:WEST+8'h40]})) begin
      $display("Expected actual heading to be around %h but got %h", WEST, iDUT.actl_hdng);
      $stop();
    end

    if (!(iPHYS.heading_robot[19:8] inside {[WEST-8'h40:WEST+8'h40]})) begin
      $display("Expected physics heading to be around %h but got %h", WEST, iPHYS.heading_robot[19:8]);
      $stop();
    end

    $display("All tests passed!!");
    $stop();
	
  end


  
  always
    #5 clk = ~clk;
	
endmodule
