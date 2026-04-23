module piezo_drv_tb;

// Stimulus signals
logic clk;
logic rst_n;
logic fanfare;
logic batt_low;

// Output signals
logic piezo;
logic piezo_n;

// Instantiate the piezo driver with parameter for fast simulation
piezo_drv #(.FAST_SIM(1)) dut(
    .clk(clk),
    .rst_n(rst_n),
    .fanfare(fanfare),
    .batt_low(batt_low),
    .piezo(piezo),
    .piezo_n(piezo_n)
);

// 50 MHz clock
always #10 clk = ~clk; // 20 ns period

initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    fanfare = 0;
    batt_low = 0;

    @( negedge clk );
    rst_n = 1; // Release reset
    repeat (5) @( negedge clk );

    // Test case 1: Trigger fanfare
    fanfare = 1;

    // Wait for some time to observe the output
    repeat (5000000) @( negedge clk );

    // Test case 2: Trigger battery low alert
    batt_low = 1;

    // Wait for some time to observe the output
    repeat (5000000) @( negedge clk );

    // Test case 3: Trigger both fanfare and battery low
    fanfare = 1;
    batt_low = 1;

    // Wait for some time to observe the output
    repeat (5000000) @( negedge clk );

    $display("Test completed.");
    $display("Jyotiraditya Patil");
    $display("TEAM: SPI KIDS");
    $stop;
end

endmodule