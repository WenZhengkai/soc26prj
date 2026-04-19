module tb_i2s_rx_core;

    // Parameters
    parameter integer SAMPLE_WIDTH = 24;
    parameter integer SLOT_WIDTH   = 32;
    parameter         WS_POL_LEFT  = 1'b0;

    // Signals
    reg         rst_n;
    reg         i2s_sck;
    reg         i2s_ws;
    reg         i2s_sd;
    wire [SAMPLE_WIDTH-1:0] sample_data;
    wire                    sample_valid;

    // Clock generation (SCK @ 100 MHz)
    initial begin
        i2s_sck = 0;
        forever #5 i2s_sck = ~i2s_sck;
    end

    // Reset logic
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // Instantiate DUT
    i2s_rx_core #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .SLOT_WIDTH  (SLOT_WIDTH),
        .WS_POL_LEFT (WS_POL_LEFT)
    ) dut (
        .rst_n       (rst_n),
        .i2s_sck     (i2s_sck),
        .i2s_ws      (i2s_ws),
        .i2s_sd      (i2s_sd),
        .sample_data (sample_data),
        .sample_valid(sample_valid)
    );

    // Test vectors
    integer cycle_count;
    integer test_idx;
    reg [SAMPLE_WIDTH-1:0] tx_data;
    integer bit_idx;
    reg [SAMPLE_WIDTH-1:0] received_data;

    initial begin
        // Init
        i2s_ws    = 0;
        i2s_sd    = 0;

        // Wait until reset done
        wait (rst_n);
        #10;

        // Repeat random send/receive process 1000 times
        for (test_idx = 0; test_idx < 1000; test_idx = test_idx + 1) begin
            // Generate random 24-bit data
            tx_data = $urandom;

            // Print the full 24-bit data being sent in 0x format
            $display("\n=== TEST #%0d : Sending Data (0x format) ===", test_idx);
            $display("Sending = 0x%h", tx_data);

            // Simulate 32 clocks where WS toggles every 32 cycles
            for (cycle_count = 0; cycle_count < SLOT_WIDTH; cycle_count = cycle_count + 1) begin

                // Toggle WS every 32 clocks
                if (cycle_count == 0)
                    i2s_ws = ~i2s_ws;

                // Drive SD only when WS==0 beginning second cycle
                if ((i2s_ws == 0) && (cycle_count > 0) && (cycle_count <= SAMPLE_WIDTH)) begin
                    bit_idx = SAMPLE_WIDTH - cycle_count; 
                    i2s_sd = tx_data[bit_idx]; // MSB → LSB
                end else begin
                    i2s_sd = 0;
                end

                #5; // half cycle; sampled at posedge

                // Check receive and store received data
                if (sample_valid) begin
                    received_data = sample_data;
                    // Print received data in hexadecimal format (0x format)
                    $display(">>> Received @ CLK %0d: 0x%h", cycle_count, received_data);
                end

                #5;
            end
        end

        $display("\n*** TESTBENCH DONE ***");
        $finish;
    end

endmodule