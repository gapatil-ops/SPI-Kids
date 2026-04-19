module SPI_main_tb();

  
  reg clk, rst_n;
  reg wrt;
  reg [15:0] wt_data;
  wire [15:0] rd_data;
  wire done;
  wire SS_n, SCLK, MOSI, MISO, INT;

  // Instantiate DUT
  SPI_main iDUT(
    .clk(clk),
    .rst_n(rst_n),
    .wrt(wrt),
    .wt_data(wt_data),
    .MISO(MISO),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .done(done),
    .rd_data(rd_data)
  );

  // Instantiate the Inertial Sensor Model
  SPI_iNEMO1 iNEMO(
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MISO(MISO),
    .MOSI(MOSI),
    .INT(INT)
  );

  // Generate a 50MHz system clock (20ns period)
  initial clk = 0;
  always #10 clk = ~clk;

  // Main test sequence
  initial begin
    // Initialize system into a known state
    rst_n = 0;
    wrt = 0;
    wt_data = 16'h0000;
    
    // Apply active-low reset
    @(negedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // TEST 1: Read the WHO_AM_I register
    // Command 0x8F00: Read bit (1) | Address 0x0F | Dummy data 0x00
    $display("Testing WHO_AM_I (Address 0x0F)");
    send_cmd(16'h8F00); 
    if (rd_data[7:0] === 8'h6A)
      $display("SUCCESS: WHO_AM_I returned 0x6A");
    else
      $display("FAILURE: WHO_AM_I returned 0x%h", rd_data[7:0]);

    // TEST 2: Configure the Interrupt register
    // Command 0x0D02: Write bit (0) | Address 0x0D | Data 0x02
    $display("Configuring INT register (Address 0x0D)");
    send_cmd(16'h0D02);

    // TEST 3: Wait for the sensor to signal that new data is ready
    $display("Waiting for INT signal...");
    fork
      begin : timeout
        // Safety mechanism to prevent infinite simulation loops
        repeat(100000) @(posedge clk);
        $display("FAILURE: Timed out waiting for INT");
        $stop;
      end
      begin : wait_for_int
        // Wait for the sensor to pulse the INT line high
        @(posedge INT);
        disable timeout;
        $display("INT asserted. Reading Yaw rate (Addresses 0x26, 0x27)");
        
        // Read Yaw rate Low byte (Register 0x26)
        send_cmd(16'hA600);
        $display("YawL: 0x%h", rd_data[7:0]);
        
        // Read Yaw rate High byte (Register 0x27)
        send_cmd(16'hA700);
        $display("YawH: 0x%h", rd_data[7:0]);
      end
    join

    $display("All tests completed. - Geet Patil, gapatil");
    $stop;
  end

  // Helper task to handle the handshake for a single 16-bit transaction
  task send_cmd(input [15:0] cmd);
    begin
      @(negedge clk);
      wt_data = cmd;     // Load the command to be sent
      wrt = 1;           // Trigger the SPI_main FSM
      @(negedge clk);
      wrt = 0;           // Clear trigger after 1 clock cycle
      @(posedge done);   // Wait for the FSM to finish 16 bits + porches
      repeat(5) @(posedge clk); 
    end
  endtask

endmodule