module piezo_drv_test(clk, RST_n, fanfare, batt_low, piezo, piezo_n);

input clk;
input RST_n; // Asynchronous reset input (active low)
input fanfare;
input batt_low;
output piezo;
output piezo_n;

// Instantiate reset synch module
logic rst_n;
reset_synch iRST_SYNC(
    .clk(clk),
    .RST_n(RST_n),
    .rst_n(rst_n)
);

// Instantiate the piezo driver
piezo_drv #(.FAST_SIM(0)) iPIEZO_DRV(
    .clk(clk),
    .rst_n(rst_n),
    .fanfare(fanfare),
    .batt_low(batt_low),
    .piezo(piezo),
    .piezo_n(piezo_n)
);

endmodule