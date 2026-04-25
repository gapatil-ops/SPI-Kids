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
  output logic en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
  input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
  input lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
  output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID
  
  // << Your declarations of states, regs, wires, ...>>
  typedef enum logic[2:0] {CHILLIN, HDNG, MV_ACCEL, DECEL, DECEL_FAST} state_t;

  logic lft_opn_prev, lft_opn_rise, rght_opn_prev, rght_opn_rise;
  state_t state, nxt_state;

  logic init_frwrd, inc_frwrd, dec_frwrd, dec_frwrd_fast;
  
  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  
  // Generate block to help us increment faster if we want to simulate faster
  logic [5:0] frwrd_inc;

  generate 
    if (FAST_SIM) begin
        assign frwrd_inc = 6'h18;
    end else begin
        assign frwrd_inc = 6'h02;
    end
  endgenerate
  
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

  /// Your implementation of ancillary circuits and SM ///	

  // RISING EDGE DETECTOR FOR LEFT AND RIGHT OPEN
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      lft_opn_prev <= '1;
      rght_opn_prev <= '1;
    end else begin
      lft_opn_prev <= lft_opn;
      rght_opn_prev <= rght_opn;
    end
  end

  assign lft_opn_rise = lft_opn && !lft_opn_prev;
  assign rght_opn_rise = rght_opn && !rght_opn_prev;


  // FLOPS FOR STATE MACHINE
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= CHILLIN;
    else 
      state <= nxt_state;


  // Flopping strt_hdng to conform with pipeline of dsrd_hdng_adj from IR_math
  logic strt_hdng_ff;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      strt_hdng_ff <= 1'b0;
    else
      strt_hdng_ff <= strt_hdng;
  end


  // LOGIC FOR STATE MACHINE (en_fusion logic in there)

  //////////////////////////
  //////////////////////////
  /// NEED_FOR_SPEED_SM ////
  //////////////////////////
  //////////////////////////
  always_comb begin

    nxt_state = state;
    moving = 1'b0;
    mv_cmplt = 1'b0;
    init_frwrd = 1'b0;
    inc_frwrd = 1'b0;
    dec_frwrd = 1'b0;
    dec_frwrd_fast = 1'b0;
    en_fusion = 1'b0;

    case (state)

      CHILLIN: begin 
        if (strt_hdng_ff) begin // When we get a strt_hdng signal, we go to the state for adjusting the heading
          nxt_state = HDNG;
        end else if (strt_mv) begin // But if we get a start move command, we go to the state for moving
          nxt_state = MV_ACCEL;
          init_frwrd = 1'b1;
        end
      end

      HDNG: begin
        if (!at_hdng) begin // While we aren't the heading, we tell the PID to keep calculating to let us turn
          moving = 1'b1;
        end else begin // Once we reach the heading, we asset that the move is complete and go back to chillin
          mv_cmplt = 1'b1;
          nxt_state = CHILLIN;
        end
      end

      MV_ACCEL: begin // While in our move/accelerate state, we asserting and increment our forward speed register to saturation
        moving = 1'b1;
        inc_frwrd = 1'b1;
        
        if (frwrd_spd > (MAX_FRWRD/2)) // If we're moving and have reached a decent speed, we want to now use the IR-fusion to adjust drift 
          en_fusion = 1'b1;

        if (~frwrd_opn) // If we encounter a wall, we want to decelerate fast
          nxt_state = DECEL_FAST;
        else if ((stp_lft && lft_opn_rise) || (stp_rght && rght_opn_rise)) // If we encounter an open path that matches our stop condition,
                                                                           // we also want to decelerate but not as fast
          nxt_state = DECEL;
      end

      DECEL: begin // While in regular decelerate, we assert the regular decelerate signal for our speed register
        dec_frwrd = 1'b1;
        moving = 1'b1;
        if (~|frwrd_spd) begin // If forward speed == 0
          moving = 1'b0;
          mv_cmplt = 1'b1;
          nxt_state = CHILLIN;
        end
      end

      DECEL_FAST: begin // While in decelerate fast, we assert the decelerate fast signal for our speed register
        dec_frwrd_fast = 1'b1;
        moving = 1'b1;
        if (~|frwrd_spd) begin // If forward speed == 0
          moving = 1'b0;
          mv_cmplt = 1'b1;
          nxt_state = CHILLIN;
        end
      end

      default: begin // In case an alpha particle flips a bit, we want to be able to return to our original state
        nxt_state = CHILLIN;
      end

    endcase

  end



endmodule
  