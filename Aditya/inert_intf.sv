//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of mazeRunner.  Fusion correction     //
// comes from IR_Dtrm when en_fusion is high.   //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,IR_Dtrm,
                  SS_n,SCLK,MOSI,MISO,INT,moving,en_fusion);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;							// SPI input from inertial sensor
  input INT;							// goes high when measurement ready
  input strt_cal;						// initiate claibration of yaw readings
  input moving;							// Only integrate yaw when going
  input en_fusion;						// do fusion corr only when forward at decent clip
  input [8:0] IR_Dtrm;					// derivative term of IR sensors (used for fusion)
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs
 

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////
  logic INT1, INT2;		// double flop INT for metastability reasons
  logic [7:0] yaw_L, yaw_H;	// holding registers for low and high byte of yaw rate reading from inertial sensor
  logic [15:0] timer;      // used for waiting before initialization
  
  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  logic wrt;					// goes high for 1 clock to write command to SPI monarch
  logic C_Y_H, C_Y_L;       // command bits to read high and low byte of yaw rate from inertial sensor
  logic [15:0] cmd;			// command to be sent to SPI monarch
  logic vld;					// goes high for 1 clock when new yaw rate is available

  //////////////////////////////////////////////////////////////
  // Declare any needed internal signals that connect blocks //
  ////////////////////////////////////////////////////////////
  wire done;
  wire [15:0] inert_data;		// Data back from inertial sensor (only lower 8-bits used)
  wire signed [15:0] yaw_rt;
  
  
  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum logic [2:0] {INIT_1, INIT_2, INIT_3, INIT_DONE, READ_L, READ_H, READ_DONE, VALID} state_t;
  state_t state, next_state;
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
                 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wt_data(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and gaurdrail info and produces a heading reading            //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),
                        .vld(vld),.rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),
						.en_fusion(en_fusion),.IR_Dtrm(IR_Dtrm),.heading(heading));

  // State flops
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= INIT_1;
    else
      state <= next_state;
  end
	
  // Timer 
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
     timer <= 0;
   else
     timer <= timer + 1;
  end

  // Holding registers for yaw rate reading from inertial sensor
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      yaw_L <= 0;
    else if (C_Y_L)
      yaw_L <= inert_data[7:0];
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      yaw_H <= 0;
    else if (C_Y_H)
      yaw_H <= inert_data[7:0];
  end

  assign yaw_rt = {yaw_H, yaw_L};	// Combine high and low byte to form signed yaw rate reading

  // Double flop INT for metastability reasons
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      INT1 <= 0;
      INT2 <= 0;
    end
    else begin
      INT1 <= INT;
      INT2 <= INT1;
    end
  end

  // State transition logic for state machine
  always_comb begin 
    // Default outputs
    wrt = 0;
    C_Y_H = 0;
    C_Y_L = 0;
    vld = 0;
    cmd = 0;
    next_state = state;
    case (state)
      INIT_2: begin
        cmd = 16'h1160;
        if (done) begin
          wrt = 1;
          next_state = INIT_3;
        end
      end
      INIT_3: begin
        cmd = 16'h1440;
        if (done) begin
          wrt = 1;
          next_state = INIT_DONE;
        end
      end
      INIT_DONE: begin
        if (done)
          next_state = READ_L;
      end
      READ_L: begin
        cmd = 16'hA6xx;	// command to read low byte of yaw rate
        if (INT2) begin
          wrt = 1;
          next_state = READ_H;
        end
      end
      READ_H: begin
        cmd = 16'hA7xx;	// command to read high byte of yaw rate
        if (done) begin
          wrt = 1;
          C_Y_L = 1;	// latch low byte into yaw_L reg
          next_state = READ_DONE;
        end
      end
      READ_DONE: begin
        if (done) begin
          C_Y_H = 1;	// latch high byte into yaw_H reg
          next_state = VALID;
        end
      end 
      VALID: begin
        vld = 1;		// new yaw rate reading is available
        next_state = READ_L;	// go get next reading
      end
      // Default is INIT_1
      default: begin
        cmd = 16'h0D02;
        if (&timer) begin
          wrt = 1;
          next_state = INIT_2;
        end
      end
    endcase
    
  end
 
endmodule
	  