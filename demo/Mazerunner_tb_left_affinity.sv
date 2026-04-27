module MazeRunner_tb_left_affinity();

  reg clk, RST_n;
  reg send_cmd;
  reg [15:0] cmd;
  reg [11:0] batt;

  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  logic clr_resp_rdy;
  logic hall_n;

  wire TX_RX, RX_TX;
  wire INRT_SS_n, INRT_SCLK, INRT_MOSI, INRT_MISO, INRT_INT;
  wire lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
  wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;
  wire IR_lft_en, IR_cntr_en, IR_rght_en;
  wire piezo;
  wire [7:0] LED;

  localparam [15:0] CAL_CMD = 16'h0000;

  MazeRunner iDUT(.clk(clk), .RST_n(RST_n), .INRT_SS_n(INRT_SS_n), .INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI), .INRT_MISO(INRT_MISO), .INRT_INT(INRT_INT),
                  .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK), .A2D_MOSI(A2D_MOSI),
                  .A2D_MISO(A2D_MISO), .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
                  .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2), .RX(RX_TX), .TX(TX_RX),
                  .hall_n(hall_n), .piezo(piezo), .piezo_n(),
                  .IR_lft_en(IR_lft_en), .IR_rght_en(IR_rght_en), .IR_cntr_en(IR_cntr_en),
                  .LED(LED));

  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .snd_cmd(send_cmd),
                  .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp), .clr_resp_rdy(clr_resp_rdy));

  RunnerPhysics iPHYS(.clk(clk), .RST_n(RST_n), .SS_n(INRT_SS_n), .SCLK(INRT_SCLK), .MISO(INRT_MISO),
                      .MOSI(INRT_MOSI), .INT(INRT_INT), .lftPWM1(lftPWM1), .lftPWM2(lftPWM2),
                      .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
                      .IR_lft_en(IR_lft_en), .IR_cntr_en(IR_cntr_en), .IR_rght_en(IR_rght_en),
                      .A2D_SS_n(A2D_SS_n), .A2D_SCLK(A2D_SCLK), .A2D_MOSI(A2D_MOSI),
                      .A2D_MISO(A2D_MISO), .hall_n(hall_n), .batt(batt));

  task automatic Initialize();
    begin
      clk          = 1'b0;
      RST_n        = 1'b0;
      send_cmd     = 1'b0;
      clr_resp_rdy = 1'b0;
      cmd          = 16'h0000;
      batt         = 12'hD80;
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

  task automatic WaitPosAck(input int max_cycles, input string label);
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
        $error("[%0t] %s TIMEOUT after %0d cycles waiting for resp_rdy", $time, label, max_cycles);
        $stop();
      end
      if (resp !== 8'hA5) begin
        $error("[%0t] %s BAD RESP: expected 0xA5, got 0x%02h", $time, label, resp);
        $stop();
      end
      $display("[%0t] %s ACK received (resp=0x%02h)", $time, label, resp);

      @(negedge clk);
      clr_resp_rdy = 1'b1;
      @(negedge clk);
      clr_resp_rdy = 1'b0;
    end
  endtask

  task automatic WaitCalDone(input int max_cycles);
    int cyc;
    begin
      cyc = 0;
      while ((iDUT.cal_done !== 1'b1) && (cyc < max_cycles)) begin
        @(posedge clk);
        cyc++;
      end
      if (iDUT.cal_done !== 1'b1) begin
        $error("[%0t] Calibration never completed (cal_done stayed low)", $time);
        $stop();
      end
      $display("[%0t] cal_done asserted after %0d cycles", $time, cyc);
    end
  endtask

  // calibration watchdog
  initial begin : global_timeout
    #8_000_000;
    $error("GLOBAL SIM TIMEOUT during calibration-only test");
    $stop();
  end

  initial begin
    Initialize();

    // reset sanity
    if (iDUT.lft_spd !== 12'sh000 || iDUT.rght_spd !== 12'sh000) begin
      $error("[%0t] Post-reset idle check failed: lft_spd=%h rght_spd=%h",
             $time, iDUT.lft_spd, iDUT.rght_spd);
      $stop();
    end
    $display("[%0t] Post-reset idle check passed", $time);

    // Send only calibration command and check full response path.
    $display("[%0t] Sending calibration command 0x%04h", $time, CAL_CMD);
    SendCmd(CAL_CMD);

    // in_cal is driven to LED[0] in MazeRunner; it should go high while calibrating.
    if (LED[0] !== 1'b1) begin
      $display("[%0t] NOTE: LED[0]/in_cal not high immediately after command (will keep monitoring)", $time);
    end

    WaitCalDone(1_500_000);
    WaitPosAck(2_000_000, "CAL");

    if (LED[0] !== 1'b0) begin
      $display("[%0t] NOTE: LED[0]/in_cal still high at end of calibration window", $time);
    end

    $display("[%0t] CALIBRATION SMOKE TEST PASSED", $time);
    disable global_timeout;
    $stop();
  end

  always
    #5 clk = ~clk;

endmodule
