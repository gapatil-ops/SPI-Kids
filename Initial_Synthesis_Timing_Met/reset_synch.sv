module reset_synch(clk, RST_n, rst_n);

input clk;
input RST_n; // Asynchronous reset input (active low)
output logic rst_n; // Synchronized reset output (active low)

logic rst_sync_0;

always_ff @( negedge clk, negedge RST_n ) begin
    if (!RST_n) begin
        rst_sync_0 <= 0; // Assert reset synchronously
        rst_n <= 0; // Assert output reset
    end else begin
        rst_sync_0 <= 1; // Deassert intermediate sync stage
        rst_n <= rst_sync_0; // Output follows the intermediate stage
    end
end

endmodule