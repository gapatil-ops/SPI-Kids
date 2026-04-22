module SPI_main_tb();

    logic clk, rst_n, wrt, MISO, SS_n, SCLK, MOSI, done, INT;
    logic [15:0] wt_data, rd_data;
    

    SPI_main iSPI(.clk(clk), .rst_n(rst_n), .wrt(wrt), .wt_data(wt_data), .MISO(MISO), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), 
                  .done(done), .rd_data(rd_data));
    SPI_iNEMO1 iNEMO1(.SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT));

    initial begin
        rst_n = 1'b0;
        clk = 1'b0;
        wrt = 1'b0;
        wt_data = 16'h0;

        @(negedge clk);
        rst_n = 1'b1;

        // TEST 1: Read from the WHO_AM_I register with address 7'0F - 1 at bit 8 since reading and don't care for 2nd byte since reading 
        wt_data = 16'h8Fxx;
        wrt = 1'b1;

        @(negedge clk)
        wrt = 1'b0; // deassert write so we aren't doing repeated writes once finished

        while (done !== 1'b1) @(negedge clk);
        
        if (rd_data != 16'hxx6A) begin
            $display("Expected to read 16'hxx6A but got %h", rd_data);
            $stop();
        end

        // TEST 2: Configure the NEMO module to assert INT when it has new data by writing to the INT register
        // Has address 7'h0D and we want to write 8'h02 to configure it

        wt_data = 16'h0D02;
        wrt = 1'b1;

        @(negedge clk)
        wrt = 1'b0;
        
        while (done !== 1'b1) @(negedge clk); // wait for SPI module to finish writing
        if (iNEMO1.NEMO_setup !== 1'b1) begin
            $display("NEMO_setup should be asserted since we activated interrupts but wasn't");
            $stop();
        end

        // TEST 3: Read from YAW registers

        // LOW BYTE
        wt_data = 16'hA6xx;
        wrt = 1'b1;

        @(negedge clk)
        wrt = 1'b0;

        while (done !== 1'b1) @(negedge clk);
        
        if (rd_data != 16'hxx90) begin
            $display("Expected to read 16'hxx90 but got %h", rd_data);
            $stop();
        end


        // HIGH BYTE
        wt_data = 16'hA7xx;
        wrt = 1'b1;

        @(negedge clk)
        wrt = 1'b0;

        while (done !== 1'b1) @(negedge clk);
        
        if (rd_data != 16'hxx7D) begin
            $display("Expected to read 16'hxx7D but got %h", rd_data);
            $stop();
        end

        // TEST 3: Read from PITCH registers
        wt_data = 16'hA2xx;
        wrt = 1'b1;

        @(negedge clk)
        wrt = 1'b0;

        while (done !== 1'b1) @(negedge clk);
        
        if (rd_data != 16'hxx46) begin
            $display("Expected to read 16'hxx46 but got %h", rd_data);
            $stop();
        end

        wt_data = 16'hA3xx;
        wrt = 1'b1;

        @(negedge clk)
        wrt = 1'b0;

        while (done !== 1'b1) @(negedge clk);
        
        if (rd_data != 16'hxxFD) begin
            $display("Expected to read 16'hxxFD but got %h", rd_data);
            $stop();
        end

        if (iNEMO1.NEMO_setup !== 1'b0) begin
            $display("NEMO_setup should be deasserted since we read from PITCH");
            $stop();
        end

        $display("Yahoo! Passed all tests");
        $stop();
    end

    always
        #5 clk = ~clk;
    
endmodule