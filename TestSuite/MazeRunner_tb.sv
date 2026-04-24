module MazeRunner_tb();
  
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
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED());
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .snd_cmd(send_cmd),
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


					 
  initial begin

  /// Your magic goes here ///
  clk = 0;
  RST_n = 0;
  send_cmd = 0;
  batt = 12'hD80; // nominal battery voltage

  

  // TEST 0: IDLE
  repeat (3) @(negedge clk);
  RST_n = 1; // release reset

  repeat (131072) @(negedge clk);

    if (iDUT.lft_spd !== 12'h000 || iDUT.rght_spd !== 12'h000) begin
      $display("ERR: Control signals (lft_spd/rght_spd) are not zero during idle!");
    end 
    // 2. Check if the physics model is actually moving
    else if (iPHYS.omega_sum !== 17'h00000) begin
      $display("ERR: Physical model reports movement (omega_sum) during idle!");
    end 
    else begin
      $display("SUCCESS: Test 0 Passed! Robot is stationary.");
    end

  

    $stop();
  
  // TEST 1: Calibration and handshaking

  cmd = 4'h000; // Calibration command
  send_cmd = 1; // Assert to send command
  @(negedge clk);

  wait (cmd_sent); // Wait for command to be sent
  send_cmd = 0; // De-assert after sending

  $display("Info: Calibration command sent, waiting for calibration to complete...");

    if (resp !== 8'hA5) begin
      $display("ERR: Did not receive expected response (0xA5) from MazeRunner after reset");
    end   
    else if (!resp_rdy) begin
      $display("ERR: Response ready signal (resp_rdy) was not asserted by MazeRunner");
    end 
    else begin
      $display("SUCCESS: Test 1 Passed! Received correct response from MazeRunner.");
    end



  // TEST 2: Basic movement

  cmd = 4'h2000; // moving command to stop at lft opening;
  send_cmd = 1; // Assert to send command
  @(negedge clk);
  wait (cmd_sent); // Wait for command to be sent
  send_cmd = 0; // De-assert after sending

  repeat(20000) @(posedge clk);

  if (iPHYS.omega_sum > 17'h00000) begin
    $display("SUCCESS: Robot is moving. omega_sum: %h", iPHYS.omega_sum);
  end else begin
    $display("ERR: Robot did not accelerate for left move!");
  end

  // Wait for the move to finish and check the response
  wait(resp_rdy); 
  if (resp !== 8'hA5) begin
    $display("ERR: Move Left failed or wrong response. Got: %h", resp);
  end else begin
    $display("SUCCESS: Test 2.1 Passed! Found Left opening.");
  end
  
  clr_resp_rdy = 1;
  @(negedge clk);
  clr_resp_rdy = 0;

 // checking to stop at right opening
  cmd = 4'h2001; // moving command to stop at lft opening;
  send_cmd = 1; // Assert to send command
  @(negedge clk);
  wait (cmd_sent); // Wait for command to be sent
  send_cmd = 0; // De-assert after sending

repeat(20000) @(posedge clk);

  if (iPHYS.omega_sum > 17'h00000) begin
    $display("SUCCESS: Robot is moving. omega_sum: %h", iPHYS.omega_sum);
  end else begin
    $display("ERR: Robot did not accelerate for left move!");
  end

  // Wait for the move to finish and check the response
  wait(resp_rdy); 
  if (resp !== 8'hA5) begin
    $display("ERR: Move Left failed or wrong response. Got: %h", resp);
  end else begin
    $display("SUCCESS: Test 2.2 Passed! Found fight opening.");
  end
  
  clr_resp_rdy = 1;
  @(negedge clk);
  clr_resp_rdy = 0;

  // TEST 3: Heading change, send command to change heading to west
  cmd = 4'h13FF; // Heading change command to west
  send_cmd = 1; // Assert to send command
  @(negedge clk);
  wait (cmd_sent); // Wait for command to be sent
  send_cmd = 0; // De-assert after sending

  $display("Info: Heading change command sent, waiting for heading adjustment...");

  repeat(20000) @(posedge clk);

  // Wait for the heading change to complete and check the response
  wait(resp_rdy);
  if (resp !== 8'hA5) begin
    $display("ERR: Heading change failed or wrong response. Got: %h", resp);
  end else begin
    $display("SUCCESS: Test 3 Passed! Heading changed to west.");
  end

    $display("All tests passed!!");
    $stop();
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule
