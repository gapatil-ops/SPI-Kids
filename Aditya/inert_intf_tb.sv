module inert_intf_tb;

// Stimulus signals
logic clk;
logic rst_n;
logic strt_cal;
logic en_fusion;
logic [8:0] IR_Dtrm;
logic moving;

// Output signals
logic cal_done;
logic rdy;
logic signed [11:0] heading;

// SPI signals
wire SS_n, SCLK, MOSI;
wire MISO;		// This will be driven by the testbench to simulate the inertial sensor's response
logic INT;        // This will be driven by the testbench to simulate an interrupt from the inertial sensor

// Instantiate the inertial interface
inert_intf iINTF(
    .clk(clk),
    .rst_n(rst_n),
    .strt_cal(strt_cal),
    .en_fusion(en_fusion),
    .IR_Dtrm(IR_Dtrm),
    .moving(moving),
    .cal_done(cal_done),
    .rdy(rdy),
    .heading(heading),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .INT(INT)
);

// Instantiate SPI_NEMO2 to simulate the inertial sensor
// Use inert_data2.hex to connect to the SPI_NEMO2's internal memory
SPI_iNEMO2 iSPI(
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .INT(INT)
);

// Testbench stimulus
initial begin
    clk = 0;
    rst_n = 0;
    strt_cal = 0;
    en_fusion = 0;
    IR_Dtrm = 0;
    moving = 0;

    @(negedge clk);
    rst_n = 1; // Release reset

    moving = 1; // Simulate that the system is moving to trigger data readings

    // Use fork-join to wait for NEMO_setup, having a timeout in case something goes wrong
    fork
        begin 
            // Wait for setup inside SPI_iNEMO2 to complete (this is where the SPI_NEMO2 will read the inert_data2.hex file and be ready to respond to SPI transactions)
            @(posedge iSPI.NEMO_setup);
            disable timeout1; // Disable the timeout if setup completes successfully
            $display("Calibration completed at time %0t", $time);
        end
        begin : timeout1
            // Timeout after 10000000 clock cycles
            repeat(100000000) @(negedge clk);
            $display("Timeout: Calibration did not complete within expected time.");
            $stop;
        end
    join

    // Assert strt_cal to start calibration for 1 clock cycle
    @(negedge clk);
    strt_cal = 1;
    @(negedge clk);
    strt_cal = 0;

    // Use fork-join to wait for calibration to complete, having a timeout in case something goes wrong
    fork
        begin
            @(posedge cal_done);
            disable timeout2; // Disable the timeout if calibration completes successfully
            $display("Calibration completed at time %0t", $time);
        end
        begin : timeout2
            // Timeout after 1000000 clock cycles
            repeat(1000000) @(negedge clk);
            $display("Timeout: Calibration did not complete within expected time.");
            $stop;
        end
    join

    // Run for 8 million clock cycles to allow for multiple INT assertions and data readings
    repeat(8000000) @(negedge clk);
    $display("Test completed at time %0t", $time);
    $stop;

end

always #5 clk = ~clk; // 100 MHz clock

endmodule