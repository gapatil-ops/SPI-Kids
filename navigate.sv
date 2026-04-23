module navigate(clk,rst_n,strt_hdng,strt_mv,stp_lft,stp_rght,mv_cmplt,hdng_rdy,moving,
                en_fusion,at_hdng,lft_opn,rght_opn,frwrd_opn,frwrd_spd);
				
  parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
  input clk,rst_n;					// 50MHz clock and asynch active low reset
  input strt_hdng;					// indicates should start a new heading
  input strt_mv;					// indicates should start a new forward move
  input stp_lft;					// indicates should stop at first left opening
  input stp_rght;					// indicates should stop at first right opening
  input hdng_rdy;					// new heading reading ready....used to pace frwrd_spd increments
  output logic mv_cmplt;			// asserted when heading or forward move complete
  output logic moving;				// enables integration in PID and in inertial_integrator
  output en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
  input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
  input lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
  output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID
  
  // << Your declarations of states, regs, wires, ...>>
  
  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  logic [5:0] frwrd_inc;
  logic init_frwrd, inc_frwrd, dec_frwrd, dec_frwrd_fast;
  logic lft_opn_flopped, rght_opn_flopped;
  logic lft_opn_edge, rght_opn_edge;
  
  ////////////////////////////////
  // Now form forward register //
  //////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  frwrd_spd <= 11'h000;
	else if (init_frwrd)
	  frwrd_spd <= MIN_FRWRD;									// min speed to get motors moving
	else if (hdng_rdy && inc_frwrd && (frwrd_spd<MAX_FRWRD))	// max out at 400 of 7FF for control head room
	  frwrd_spd <= frwrd_spd + {5'h00,frwrd_inc};
	else if (hdng_rdy && (frwrd_spd>11'h000) && (dec_frwrd | dec_frwrd_fast))
	  frwrd_spd <= ((dec_frwrd_fast) && (frwrd_spd>{2'h0,frwrd_inc,3'b000})) ? frwrd_spd - {2'h0,frwrd_inc,3'b000} : // 8x accel rate
                    (dec_frwrd_fast) ? 11'h000 :	  // if non zero but smaller than dec amnt set to zero.
	                (frwrd_spd>{4'h0,frwrd_inc,1'b0}) ? frwrd_spd - {4'h0,frwrd_inc,1'b0} : // slow down at 2x accel rate
					11'h000;

  // << Your implementation of ancillary circuits and SM >>	

  // Speeding up rate of accel/decel for simulation
  generate if (FAST_SIM) begin
    assign frwrd_inc = 6'h18;
  end else begin
    assign frwrd_inc = 6'h02;
  end
  endgenerate

  // Rising edge detectors for lft_opn and rght_opn
  always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n) begin
      lft_opn_flopped <= 0;
      rght_opn_flopped <= 0;
    end
    else begin
      lft_opn_flopped <= lft_opn;
      rght_opn_flopped <= rght_opn;
    end
  end

  assign lft_opn_edge = lft_opn & ~lft_opn_flopped;
  assign rght_opn_edge = rght_opn & ~rght_opn_flopped;

  // En_fusion signal implementation
  assign en_fusion = (frwrd_spd > (MAX_FRWRD >> 1));

  // FSM Implementation
  // States
  typedef enum logic [2:0] { IDLE, CHANGE_HDNG, ACCEL, FAST_DECEL, SLOW_DECEL } state_t;
  state_t state, next_state;

  // State flops
  always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
      state <= IDLE;
    else 
      state <= next_state;
  end

  // FSM combinational logic
  always_comb begin 
    // Default outputs
    mv_cmplt = 0;
    moving = 0;
    init_frwrd = 0;
    inc_frwrd = 0;
    dec_frwrd = 0;
    dec_frwrd_fast = 0;
    next_state = state;

    case(state)
      CHANGE_HDNG: begin
        // Assert moving and wait till at_hdng is asserted
        // Transition to idle while asserting mv_cmplt
        moving = 1;
        if (at_hdng) begin
          next_state = IDLE;
          mv_cmplt = 1;
        end
      end

      ACCEL: begin
        // Ramp up
        inc_frwrd = 1;
        moving = 1;
        // Transition to fast decel if obstacle in front
        // Slow decel if opening on the side
        if (~frwrd_opn)
          next_state = FAST_DECEL;
        else if ((lft_opn_edge && stp_lft) || (rght_opn_edge && stp_rght))
          next_state = SLOW_DECEL;
      end

      FAST_DECEL: begin
        // Assert fast decel until stopped, then assert mv_cmplt and transition to idle
        dec_frwrd_fast = 1;
        moving = 1;
        if (frwrd_spd == 0) begin
          next_state = IDLE;
          mv_cmplt = 1;
        end
      end

      SLOW_DECEL: begin
        // Assert slow decel until stopped, then assert mv_cmplt and transition to idle
        dec_frwrd = 1;
        moving = 1;
        if (frwrd_spd == 0) begin
          next_state = IDLE;
          mv_cmplt = 1;
        end
      end

      // Default case is IDLE: wait for strt_hdng or strt_mv to transition to appropriate state
      default: begin
        if (strt_hdng)
          next_state = CHANGE_HDNG;
        else if (strt_mv) begin
          next_state = ACCEL;
          init_frwrd = 1;
        end
      end
    endcase
  end

endmodule
  