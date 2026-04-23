module navigate_tb();

  //// Declare stimulus as type reg ////
  reg clk,rst_n;			// 50MHz clock and asynch active low reset
  reg strt_hdng;			// indicates to start a new heading sequence
  reg strt_mv;				// indicates a new forward movement occurring
  reg stp_lft;				// indicates move should stop at a left opening
  reg stp_rght;				// indicates move should stop at a right opening
  reg hdng_rdy;				// used to pace frwrd_spd increments
  reg at_hdng;				// asserted by PID when new heading is close enough
  reg lft_opn;				// from IR sensor....indicates opening in maze to left
  reg rght_opn;				// from IR sensor....indicates opening in maze to right
  reg frwrd_opn;			// from IR sensor....indicates opening in front
  
  //// declare outputs monitored of type wire ////
  wire mv_cmplt;			// should be asserted at end of move
  wire moving;				// should be asserted at all times not in IDLE
  wire en_fusion;			// should be asserted whenever frwrd_spd>MAX_FRWRD
  wire [10:0] frwrd_spd;	// the primary output...forward motor speed

  localparam FAST_SIM = 1;	// we always simulate with FAST_SIM on
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  navigate #(FAST_SIM) iDUT(.clk(clk),.rst_n(rst_n),.strt_hdng(strt_hdng),.strt_mv(strt_mv),
                .stp_lft(stp_lft),.stp_rght(stp_rght),.mv_cmplt(mv_cmplt),.hdng_rdy(hdng_rdy),
				.moving(moving),.en_fusion(en_fusion),.at_hdng(at_hdng),.lft_opn(lft_opn),
				.rght_opn(rght_opn),.frwrd_opn(frwrd_opn),.frwrd_spd(frwrd_spd));
  
  initial begin
    clk = 0;
	rst_n = 0;
	strt_hdng = 0;
	strt_mv = 0;
	stp_lft = 1;
	stp_rght = 0;
	hdng_rdy = 1;		// allow increments of frwrd_spd initially
	at_hdng = 0;
	lft_opn = 0;
	rght_opn = 0;
	frwrd_opn = 1;		// no wall in front of us
	
	@(negedge clk);		// after negege clk
	rst_n = 1;			// deassert reset
	
	assert (!moving) $display("GOOD0: moving should not be asserted when IDLE");
	else $error("ERR0: why is moving asserted now?");	
	//////////////////////////////////////////////
	// First testcase will be a heading change //
	////////////////////////////////////////////
	strt_hdng = 1;
	@(negedge clk);
	strt_hdng = 0;
	assert (moving) $display("GOOD1: moving asserted during heading change");
	else $error("ERR1: expecting moving asserted during heading change");
	repeat(5) @(negedge clk);
	at_hdng = 1;				// end the heading
	#1;							// give DUT time to respond
	assert (mv_cmplt) $display("GOOD2: mv_cmplt should be asserted when at_hdng");
	else $error("ERR2: expecting mv_cmplt to be asserted at time %t",$time);
	@(negedge clk);
	at_hdng = 0;
	
	///////////////////////////////////////////////////////////////////////////////////
	// Second testcase will be move forward looking for lft_opn, but hit wall first //
	/////////////////////////////////////////////////////////////////////////////////
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;
	assert (moving) $display("GOOD3: moving asserted during forward move");
	else $error("ERR3: expecting moving asserted during forward move");
	assert (frwrd_spd===MIN_FRWRD) $display("GOOD4: frwrd spd should have changed to MIN_FRWRD");
	else $error("ERR4: expecting frwrd_spd to have loaded MIN_FRWRD at time %t",$time);

	@(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h018) $display("GOOD5: frwrd spd should have incrementd to MIN_FRWRD+0x018");
	else $error("ERR5: expecting frwrd_spd to have incremented by 0x018 at time %t",$time);	
	
	/// Now lower hdng_rdy to ensure frwrd_spd does not increment ////
	hdng_rdy = 0;
	@(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h018) $display("GOOD6: frwrd spd should still be MIN_FRWRD+0x018");
	else $error("ERR6: expecting frwrd_spd to have maintained at MIN_FRWRD+0x018");	
	
	/// Now raise hdng_rdy back up
	hdng_rdy = 1;
	@(negedge clk);
	assert (moving) $display("GOOD7: moving should still be asserted");
	else $error("ERR7: why is moving not still asserted?");
	assert (frwrd_spd===MIN_FRWRD+11'h030) $display("GOOD8: frwrd spd should have incremented to MIN_FRWRD+0x030");
	else $error("ERR8: expecting frwrd_spd to have incremented to MIN_FRWRD+0x030 at time %t",$time);
	
	/// Now let it increment 6 more times (so 9 in total) ////
	repeat(6) @(negedge clk);
	
	/// Now let it know it has an obstacle in front ////
	frwrd_opn = 0;
	repeat(2) @(negedge clk);
	assert (frwrd_spd===MIN_FRWRD+11'h018) $display("GOOD9: frwrd spd should have decremented fast to MIN_FRWRD+0x018");
	else $error("ERR9: expecting a fast decrement of frwrd_spd at time %t",$time);	
	
	/// Now check that it properly decrements to zero ////
	repeat(2) @(negedge clk);
	assert (frwrd_spd===11'h000) $display("GOOD10: frwrd spd should be zero now");
	else $error("ERR10: expecting frwrd_spd to have decremented to zero by time %t",$time);	
	assert (mv_cmplt) $display("GOOD11: mv_cmplt should be asserted when speed hits zero");
	else $error("ERR11: expecting mv_cmplt to be asserted at time %t",$time);	

	///////////////////////////////////////////////////////////////////////////
	// Third testcase: verify IDLE after wall stop, no moving, no mv_cmplt  //
	///////////////////////////////////////////////////////////////////////////
	@(negedge clk);
	frwrd_opn = 1;				// restore clear path for next test
	assert (!moving) $display("GOOD12: moving should be deasserted back in IDLE after fast decel");
	else $error("ERR12: moving should not be asserted in IDLE at time %t",$time);
	assert (!mv_cmplt) $display("GOOD13: mv_cmplt should be deasserted in IDLE after one cycle");
	else $error("ERR13: mv_cmplt should not persist in IDLE at time %t",$time);
	assert (!en_fusion) $display("GOOD14: en_fusion should be deasserted when frwrd_spd is zero");
	else $error("ERR14: en_fusion should not be asserted when frwrd_spd is zero at time %t",$time);

	/////////////////////////////////////////////////////////////////////
	// Fourth testcase: forward move, stop at left opening (slow decel) //
	// stp_lft=1, stp_rght=0 — rising edge of lft_opn triggers slow stop
	/////////////////////////////////////////////////////////////////////
	stp_lft = 1;
	stp_rght = 0;
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;
	assert (moving) $display("GOOD15: moving asserted at start of left-opening move");
	else $error("ERR15: expecting moving asserted during forward move at time %t",$time);
	assert (frwrd_spd===MIN_FRWRD) $display("GOOD16: frwrd_spd should init to MIN_FRWRD on strt_mv");
	else $error("ERR16: expecting frwrd_spd==MIN_FRWRD at time %t",$time);

	/// Let it ramp up for several cycles ////
	repeat(8) @(negedge clk);
	assert (moving) $display("GOOD17: moving should still be asserted while accelerating");
	else $error("ERR17: moving dropped unexpectedly during accel at time %t",$time);

	/// Now assert lft_opn rising edge — should trigger slow decel ////
	lft_opn = 1;
	@(negedge clk);
	lft_opn = 0;				// lower it; edge already detected
	assert (moving) $display("GOOD18: moving should remain asserted during slow decel");
	else $error("ERR18: moving should not drop on entry to slow decel at time %t",$time);
	assert (!mv_cmplt) $display("GOOD19: mv_cmplt should not fire until speed reaches zero");
	else $error("ERR19: mv_cmplt fired too early at time %t",$time);

	/// Wait for slow decel to complete ////
	@(negedge clk);
	// Check that frwrd_spd is actively decrementing (not fast-decrementing)
	// by confirming speed dropped by 2x frwrd_inc (0x030) not 8x
	assert (frwrd_spd > 11'h000) $display("GOOD20: speed still nonzero one cycle into slow decel (not instant stop)");
	else $error("ERR20: speed went to zero too fast — may be using fast decel at time %t",$time);

	/// Wait until fully stopped ////
	wait(frwrd_spd === 11'h000);
	#1;
	assert (mv_cmplt) $display("GOOD21: mv_cmplt should fire when slow decel reaches zero");
	else $error("ERR21: mv_cmplt not asserted when frwrd_spd hit zero at time %t",$time);
	@(negedge clk);			// latch mv_cmplt / return to IDLE
	@(negedge clk);			// extra cycle — ensure FSM fully settled in IDLE before next move

	////////////////////////////////////////////////////////////////////////////
	// Fifth testcase: forward move, stop at right opening (slow decel)       //
	// stp_lft=0, stp_rght=1 — rising edge of rght_opn triggers slow stop     //
	////////////////////////////////////////////////////////////////////////////
	stp_lft = 0;
	stp_rght = 1;
	frwrd_opn = 1;
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;
	assert (moving) $display("GOOD22: moving asserted at start of right-opening move");
	else $error("ERR22: expecting moving asserted during forward move at time %t",$time);
	assert (frwrd_spd===MIN_FRWRD) $display("GOOD23: frwrd_spd should init to MIN_FRWRD on strt_mv");
	else $error("ERR23: expecting frwrd_spd==MIN_FRWRD at time %t",$time);

	/// Ramp up for several cycles ////
	repeat(8) @(negedge clk);

	/// Assert rght_opn rising edge ////
	rght_opn = 1;
	@(negedge clk);
	rght_opn = 0;
	assert (moving) $display("GOOD24: moving should remain asserted during right-side slow decel");
	else $error("ERR24: moving dropped on entry to slow decel (right) at time %t",$time);

	/// Wait until fully stopped ////
	wait(frwrd_spd === 11'h000);
	#1;
	assert (mv_cmplt) $display("GOOD25: mv_cmplt should fire when right-side slow decel reaches zero");
	else $error("ERR25: mv_cmplt not asserted after right-side slow decel at time %t",$time);
	@(negedge clk);			// latch mv_cmplt / return to IDLE
	@(negedge clk);			// extra cycle — ensure FSM fully settled in IDLE before next move
	stp_rght = 0;				// restore defaults

	/////////////////////////////////////////////////////////////////////
	// Sixth testcase: lft_opn asserted but stp_lft=0 (should ignore) //
	// Robot should continue accelerating, only wall stops it          //
	/////////////////////////////////////////////////////////////////////
	stp_lft = 0;
	stp_rght = 0;
	frwrd_opn = 1;
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;
	assert (moving) $display("GOOD26: moving asserted for stp_lft=0 test move");
	else $error("ERR26: moving not asserted at start of move at time %t",$time);

	/// Ramp up a few cycles then assert lft_opn ////
	repeat(5) @(negedge clk);
	lft_opn = 1;
	@(negedge clk);
	lft_opn = 0;
	/// Speed should still be increasing — lft_opn edge ignored when stp_lft=0 ////
	repeat(3) @(negedge clk);
	assert (moving) $display("GOOD27: moving should persist — lft_opn ignored when stp_lft=0");
	else $error("ERR27: moving dropped unexpectedly at time %t",$time);
	assert (frwrd_spd > MIN_FRWRD) $display("GOOD28: frwrd_spd should still be climbing when stp_lft=0");
	else $error("ERR28: frwrd_spd not climbing as expected at time %t",$time);

	/// Now trigger a wall stop to cleanly exit the move ////
	frwrd_opn = 0;
	wait(frwrd_spd === 11'h000);
	#1;
	assert (mv_cmplt) $display("GOOD29: mv_cmplt should fire after wall fast-decel completes");
	else $error("ERR29: mv_cmplt not asserted after wall fast-decel at time %t",$time);
	@(negedge clk);
	frwrd_opn = 1;				// restore

	//////////////////////////////////////////////////////////////////////
	// Seventh testcase: en_fusion asserted only above half MAX_FRWRD  //
	// MAX_FRWRD=0x2A0, half=0x150 — en_fusion should toggle correctly //
	//////////////////////////////////////////////////////////////////////
	stp_lft = 0;
	stp_rght = 0;
	frwrd_opn = 1;
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;

	/// Confirm en_fusion is off near MIN_FRWRD (well below half MAX_FRWRD) ////
	assert (!en_fusion) $display("GOOD30: en_fusion should be deasserted near MIN_FRWRD");
	else $error("ERR30: en_fusion should not be asserted near MIN_FRWRD at time %t",$time);

	/* /// Ramp until frwrd_spd passes half MAX_FRWRD (0x150) ////
	wait(frwrd_spd > (MAX_FRWRD >> 1));
	#1;
	assert (en_fusion) $display("GOOD31: en_fusion should be asserted once frwrd_spd > half MAX_FRWRD");
	else $error("ERR31: en_fusion not asserted above half MAX_FRWRD at time %t",$time);

	/// Now kill the move with a wall — must set frwrd_opn=0 FIRST then wait for speed to drop ////
	frwrd_opn = 0;
	@(negedge clk);		// give FSM one cycle to register wall and enter FAST_DECEL
	wait(frwrd_spd < (MAX_FRWRD >> 1));
	#1;
	assert (!en_fusion) $display("GOOD32: en_fusion should deassert when frwrd_spd drops back below half MAX_FRWRD");
	else $error("ERR32: en_fusion still asserted below half MAX_FRWRD at time %t",$time);
	wait(frwrd_spd === 11'h000);
	#1;
	assert (mv_cmplt) $display("GOOD33: mv_cmplt fires after en_fusion test wall stop");
	else $error("ERR33: mv_cmplt not asserted at end of en_fusion test at time %t",$time);
	@(negedge clk);
	frwrd_opn = 1;

	///////////////////////////////////////////////////////////////////////
	// Eighth testcase: frwrd_spd saturates at MAX_FRWRD, does not wrap //
	///////////////////////////////////////////////////////////////////////
	stp_lft = 0;
	stp_rght = 0;
	frwrd_opn = 1;
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;

	/// Let it ramp all the way to MAX ////
	wait(frwrd_spd === MAX_FRWRD);
	@(negedge clk);
	assert (frwrd_spd === MAX_FRWRD) $display("GOOD34: frwrd_spd should saturate at MAX_FRWRD and not exceed it");
	else $error("ERR34: frwrd_spd exceeded MAX_FRWRD at time %t",$time);
	assert (moving) $display("GOOD35: moving should still be asserted while cruising at MAX_FRWRD");
	else $error("ERR35: moving dropped while at MAX_FRWRD at time %t",$time);
	assert (en_fusion) $display("GOOD36: en_fusion should be asserted at MAX_FRWRD");
	else $error("ERR36: en_fusion not asserted at MAX_FRWRD at time %t",$time);

	/// Trigger wall stop to exit ////
	frwrd_opn = 0;
	wait(frwrd_spd === 11'h000);
	#1;
	assert (mv_cmplt) $display("GOOD37: mv_cmplt fires after saturation test wall stop");
	else $error("ERR37: mv_cmplt not asserted at end of saturation test at time %t",$time);
	@(negedge clk);
	frwrd_opn = 1;

	///////////////////////////////////////////////////////////////////////////
	// Ninth testcase: back-to-back heading changes work correctly           //
	// Confirm mv_cmplt pulses and moving deasserts between heading changes  //
	///////////////////////////////////////////////////////////////////////////
	strt_hdng = 1;
	@(negedge clk);
	strt_hdng = 0;
	assert (moving) $display("GOOD38: moving asserted for first of two back-to-back heading changes");
	else $error("ERR38: moving not asserted for first heading change at time %t",$time);
	repeat(3) @(negedge clk);
	at_hdng = 1;
	#1;
	assert (mv_cmplt) $display("GOOD39: mv_cmplt asserted on completion of first heading change");
	else $error("ERR39: mv_cmplt not asserted at end of first heading change at time %t",$time);
	@(negedge clk);
	at_hdng = 0;
	assert (!moving) $display("GOOD40: moving deasserted after returning to IDLE between heading changes");
	else $error("ERR40: moving should not be asserted in IDLE between headings at time %t",$time);

	/// Now immediately issue a second heading change ////
	strt_hdng = 1;
	@(negedge clk);
	strt_hdng = 0;
	assert (moving) $display("GOOD41: moving asserted for second heading change");
	else $error("ERR41: moving not asserted for second heading change at time %t",$time);
	repeat(4) @(negedge clk);
	at_hdng = 1;
	#1;
	assert (mv_cmplt) $display("GOOD42: mv_cmplt asserted on completion of second heading change");
	else $error("ERR42: mv_cmplt not asserted at end of second heading change at time %t",$time);
	@(negedge clk);
	at_hdng = 0;

	/////////////////////////////////////////////////////////////////////////
	// Tenth testcase: strt_mv asserted while rght_opn is already high    //
	// Edge detector must prevent immediate slow-decel on move start       //
	/////////////////////////////////////////////////////////////////////////
	stp_lft = 0;
	stp_rght = 1;
	rght_opn = 1;			// opening already present before move starts
	frwrd_opn = 1;
	strt_mv = 1;
	@(negedge clk);
	strt_mv = 0;
	/// Since rght_opn was already high when move started, no rising edge ///
	/// should be detected — robot should continue accelerating           ///
	repeat(4) @(negedge clk);
	assert (moving) $display("GOOD43: moving persists — pre-asserted rght_opn edge correctly ignored on move start");
	else $error("ERR43: moving dropped due to pre-asserted rght_opn — edge detect failed at time %t",$time);
	assert (frwrd_spd > MIN_FRWRD) $display("GOOD44: frwrd_spd climbing — pre-asserted rght_opn ignored correctly");
	else $error("ERR44: frwrd_spd not climbing; pre-asserted rght_opn may have caused premature stop at time %t",$time);

	/// Now deassert and reassert to create a genuine rising edge ////
	rght_opn = 0;
	@(negedge clk);
	rght_opn = 1;
	@(negedge clk);
	assert (moving) $display("GOOD45: moving remains asserted as slow decel begins on genuine rght_opn rise");
	else $error("ERR45: moving dropped immediately on rght_opn rising edge at time %t",$time);
	wait(frwrd_spd === 11'h000);
	#1;
	assert (mv_cmplt) $display("GOOD46: mv_cmplt fires after genuine rght_opn slow decel completes");
	else $error("ERR46: mv_cmplt not asserted after rght_opn slow decel at time %t",$time);
	@(negedge clk);
	rght_opn = 0;
	stp_rght = 0; */

	$display("All tests completed...did all pass?");
	$stop();
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule
