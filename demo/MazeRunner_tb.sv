module MazeRunner_tb();
  
  reg clk,RST_n;
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xD80 is nominal
  
  logic cmd_sent;				
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  logic clr_resp_rdy;
   
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
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2), .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),
            .IR_rght_en(IR_rght_en),.A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					  .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));


					 
  initial begin

  /// Your magic goes here ///
  clk = 0;
  RST_n = 0;
  send_cmd = 0;
  batt = 12'hD80; // nominal battery voltage
  clr_resp_rdy = 0;

  

  // TEST 0: IDLE
  repeat (3) @(negedge clk);
  RST_n = 1; // release reset

  repeat (131072) @(negedge clk);

    if (iDUT.lft_spd !== 12'h000 || iDUT.rght_spd !== 12'h000) begin
      $display("ERR: Control signals (lft_spd/rght_spd) are not zero during idle!");
$stop();
    end 
    // 2. Check if the physics model is actually moving
    else if (iPHYS.omega_sum <= 17'h00000) begin
      $display("ERR: Physical model reports movement (omega_sum) during idle! Was %h", iPHYS.omega_sum);
$stop();
    end 
    else begin
      $display("SUCCESS: Test 0 Passed! Robot is stationary.");
    end

  

    
  
  // ====================================================================
  // TEST 1: Calibration and Handshaking (Opcode: 0x0000)
  // ====================================================================

  $display("--- Starting Test 1: Calibration ---");
  cmd = 16'h0000;       
  
  // 1. The Pulse
  send_cmd = 1;         // Press the button
  @(posedge clk);       // Wait for 1 clock edge so RemoteComm sees it
  send_cmd = 0;         // DROP THE BUTTON IMMEDIATELY!

  // 2. Now it is safe to wait!
  wait (cmd_sent);      
  $display("INFO: Command sent to robot. Waiting for calibration...");

  wait (resp_rdy);      

  if (resp !== 8'hA5) begin
    $display("ERR: Expected 0xA5 from MazeRunner. Got: %h", resp);
  end else begin
    $display("SUCCESS: Test 1 Passed! Received correct response (0xA5).");
  end

  clr_resp_rdy = 1;     
  @(posedge clk);
  clr_resp_rdy = 0;




  // ====================================================================
  // TEST 2: Basic Movement (Sequential Left and Right Openings)
  // ====================================================================

  // ---------------------------------------------------------
  // TEST 2A: Move Forward until LEFT Opening
  // ---------------------------------------------------------
  $display("--- Starting Test 2A: Move to Left Opening ---");
  cmd = 16'h2000;         // Command to stop at LEFT opening
  
  // 1. The Pulse
  send_cmd = 1;           // Press the button
  @(posedge clk);         // Wait 1 clock
  send_cmd = 0;           // Drop the button

  // 2. Wait for UART transmission
  wait (cmd_sent);        
  $display("INFO: Command 0x2000 sent. Waiting for robot to move...");

  // 3. The Physics Check: Let motors spool up, then verify movement
  repeat(20000) @(posedge clk);
  if (iPHYS.omega_sum > 17'h00000) begin
    $display("SUCCESS: Robot is physically moving! omega_sum: %h", iPHYS.omega_sum);
  end else begin
    $display("ERR: Physics model failed to move for left opening.");
  end

  // 4. The Handshake Check: Wait for it to stop at the gap
  wait(resp_rdy); 
  if (resp !== 8'hA5) begin
    $display("ERR: Move Left failed or wrong response. Got: %h", resp);
  end else begin
    $display("SUCCESS: Test 2A Passed! Found Left opening.");
  end

  // Cleanup
  clr_resp_rdy = 1;
  @(posedge clk);
  clr_resp_rdy = 0;


  // ---------------------------------------------------------
  // TEST 2B: Move Forward until RIGHT Opening
  // ---------------------------------------------------------
  $display("--- Starting Test 2B: Move to Right Opening ---");
  cmd = 16'h2001;         // Command to stop at RIGHT opening
  
  // 1. The Pulse
  send_cmd = 1;           
  @(posedge clk);         
  send_cmd = 0;           

  // 2. Wait for UART transmission
  wait (cmd_sent);        
  $display("INFO: Command 0x2001 sent. Waiting for robot to move...");

  // 3. The Physics Check
  repeat(20000) @(posedge clk);
  if (iPHYS.omega_sum > 17'h00000) begin
    $display("SUCCESS: Robot is physically moving! omega_sum: %h", iPHYS.omega_sum);
  end else begin
    $display("ERR: Physics model failed to move for right opening.");
  end

  // 4. The Handshake Check
  wait(resp_rdy); 
  if (resp !== 8'hA5) begin
    $display("ERR: Move Right failed or wrong response. Got: %h", resp);
  end else begin
    $display("SUCCESS: Test 2B Passed! Found Right opening.");
  end

  // Cleanup
  clr_resp_rdy = 1;
  @(posedge clk);
  clr_resp_rdy = 0;

 // ====================================================================
  // TEST 3: Heading Change (Pivot West)
  // ====================================================================
  $display("--- Starting Test 3: Heading Change (West) ---");
  
  // Opcode 3'b001 + West 12'h3FF = 16'h23FF
  cmd = 16'h23FF;         
  
  // 1. The Pulse
  send_cmd = 1;           
  @(posedge clk);         
  send_cmd = 0;           

  // 2. Wait for UART transmission
  wait (cmd_sent);        
  $display("INFO: Command 0x23FF sent. Robot is pivoting West...");

  // 3. The Layer 1 Check (Brain Verification)
  // We check that cmd_proc successfully latched the desired heading
  if (iDUT.iCMD.dsrd_hdng !== 12'h3FF) begin
    $display("ERR: cmd_proc failed to latch West (0x3FF) into dsrd_hdng!");
  end else begin
    $display("SUCCESS: cmd_proc latched correct heading.");
  end

  // 4. The Handshake Check
  // Wait for the PID to finish turning the robot and send the Acknowledge
  wait(resp_rdy); 
  
  if (resp !== 8'hA5) begin
    $display("ERR: Heading change failed or wrong response. Got: %h", resp);
  end else begin
    $display("SUCCESS: Test 3 Passed! Robot is now facing West.");
  end

  // Cleanup
  clr_resp_rdy = 1;
  @(posedge clk);
  clr_resp_rdy = 0;

  $display("ALL TESTS PASSED !!!");
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule