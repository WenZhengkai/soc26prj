`timescale 1ns/1ns
`define PCLK_PERIOD 20

module testbench;

    localparam int SAMPLE_COUNT = 16;
    localparam int RD_BUF_ADDR  = 32'h0000C000;
    localparam int DONE_FLAG_ADDR = 32'h0000BFFC;
    localparam int RD_BUF_WORD_IDX = RD_BUF_ADDR >> 2;
    localparam int DONE_FLAG_WORD_IDX = DONE_FLAG_ADDR >> 2;

    reg clk;
    reg resetn;
    reg tdi;
    reg tck;

    wire tms;
    wire tdo;

    wire [7:0] b_pad_gpio_porta;
    wire uart1_rxd;
    wire uart2_rxd;
    wire timer0_extin;
    wire timer1_extin;

    reg  i2s_sd;
    wire i2s_sck;
    wire i2s_ws;

    wire flash_cs_n;
    wire flash_sclk;
    wire flash_mosi;
    wire flash_miso;
    reg  flash_miso_drv;

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    top u_soc (
        .CLK            (clk),
        .RESETn         (resetn),
        .TDI            (tdi),
        .TCK            (tck),
        .TMS            (tms),
        .TDO            (tdo),
        .b_pad_gpio_porta(b_pad_gpio_porta[7:0]),
        .uart1_rxd      (uart1_rxd),
        .uart2_rxd      (uart2_rxd),
        .uart1_txd      (),
        .uart2_txd      (),
        .timer0_extin   (timer0_extin),
        .timer1_extin   (timer1_extin),
        .i2s_sd         (i2s_sd),
        .i2s_sck        (i2s_sck),
        .i2s_ws         (i2s_ws),
        .flash_cs_n     (flash_cs_n),
        .flash_sclk     (flash_sclk),
        .flash_mosi     (flash_mosi),
        .flash_miso     (flash_miso)
    );

    assign uart1_rxd = 1'b0;
    assign uart2_rxd = 1'b0;
    assign timer0_extin = 1'b0;
    assign timer1_extin = 1'b0;
    assign flash_miso = flash_miso_drv;

    // ------------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------------
    always #(`PCLK_PERIOD/2) clk = ~clk;

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        tdi = 1'b0;
        tck = 1'b0;
        i2s_sd = 1'b0;
        flash_miso_drv = 1'b0;

        $readmemh("./cnasic_sleep/prj/keil/output/outfile.bin", u_soc.U_SRAM.memory);
        $display("[TB] RAM loaded");

        #(`PCLK_PERIOD * 20);
        resetn = 1'b1;
    end

    // ------------------------------------------------------------------
    // I2S stimulus
    // ------------------------------------------------------------------
    reg [23:0] sample_mem [0:SAMPLE_COUNT-1];
    byte unsigned exp_bytes[$];
    integer sample_idx;
    integer bit_idx;
    reg [23:0] curr_sample;
    reg ws_d1;
    wire start_left = ws_d1 && !i2s_ws;

    localparam int FLASH_BYTES = 65536;
    reg [7:0] flash_mem [0:FLASH_BYTES-1];

    initial begin
        integer i;
        for (i = 0; i < SAMPLE_COUNT; i = i + 1) begin
            sample_mem[i] = 24'h100000 + i[23:0];
            exp_bytes.push_back(sample_mem[i][7:0]);
            exp_bytes.push_back(sample_mem[i][15:8]);
            exp_bytes.push_back(sample_mem[i][23:16]);
            exp_bytes.push_back(8'h00);
        end
    end

    initial begin
        integer j;
        for (j = 0; j < FLASH_BYTES; j = j + 1)
            flash_mem[j] = 8'hFF;
    end

    always @(negedge i2s_sck or negedge resetn) begin
        if (!resetn) begin
            i2s_sd     <= 1'b0;
            sample_idx <= 0;
            bit_idx    <= -1;
            curr_sample <= 24'h0;
            ws_d1      <= 1'b1;
        end else begin
            // Detect left channel start when WS falls to 0
            if (start_left) begin
                if (sample_idx < SAMPLE_COUNT) begin
                    curr_sample <= sample_mem[sample_idx];
                    i2s_sd <= sample_mem[sample_idx][23];
                    sample_idx <= sample_idx + 1;
                end else begin
                    curr_sample <= 24'h0;
                    i2s_sd <= 1'b0;
                end
                bit_idx <= 22;
            end else if (i2s_ws == 1'b0) begin
                if (bit_idx >= 0) begin
                    i2s_sd <= curr_sample[bit_idx];
                    bit_idx <= bit_idx - 1;
                end else begin
                    i2s_sd <= 1'b0;
                end
            end else begin
                i2s_sd <= 1'b0;
            end

            ws_d1 <= i2s_ws;
        end
    end

    // ------------------------------------------------------------------
    // I2S ratio check: 32 SCK per WS half-frame
    // ------------------------------------------------------------------
    integer sck_edge_cnt;
    reg ws_d2;
    reg ws_first_skip;
    integer ws_check_cnt;
    integer error_cnt;
    integer pass_cnt;

    task automatic tb_fail(input string msg);
        begin
            error_cnt = error_cnt + 1;
            $display("[FAIL][%0t] %s", $time, msg);
        end
    endtask

    task automatic tb_pass(input string msg);
        begin
            pass_cnt = pass_cnt + 1;
            $display("[PASS][%0t] %s", $time, msg);
        end
    endtask

    always @(posedge i2s_sck or negedge resetn) begin
        if (!resetn) begin
            sck_edge_cnt <= 0;
            ws_d2 <= 1'b1;
            ws_first_skip <= 1'b1;
            ws_check_cnt <= 0;
        end else begin
            sck_edge_cnt <= sck_edge_cnt + 1;
            if ((ws_d2 != i2s_ws) && (ws_check_cnt < 5)) begin
                if (ws_first_skip) begin
                    ws_first_skip <= 1'b0;
                end else begin
                    if (sck_edge_cnt != 31)
                        tb_fail($sformatf("WS half-frame SCK count=%0d", sck_edge_cnt));
                    else
                        tb_pass("WS half-frame SCK count=31");
                end
                ws_check_cnt <= ws_check_cnt + 1;
                sck_edge_cnt <= 0;
                ws_d2 <= i2s_ws;
            end
        end
    end

    // ------------------------------------------------------------------
    // SPI monitor and scoreboard
    // ------------------------------------------------------------------
    reg [7:0] spi_shift;
    reg [2:0] spi_bit_cnt;
    reg [7:0] spi_cmd;
    reg [1:0] spi_addr_cnt;
    reg [2:0] spi_state;
    reg [23:0] spi_addr_reg;
    reg [23:0] wr_addr_reg;
    reg [23:0] rd_addr_reg;
    reg [7:0]  miso_shift;
    reg [2:0]  miso_bit_cnt;

    localparam [2:0] SPI_ST_CMD   = 3'd0;
    localparam [2:0] SPI_ST_ADDR  = 3'd1;
    localparam [2:0] SPI_ST_WDATA = 3'd2;
    localparam [2:0] SPI_ST_RDATA = 3'd3;
    localparam [2:0] SPI_ST_IGN   = 3'd4;

    always @(negedge flash_cs_n or negedge resetn) begin
        if (!resetn) begin
            spi_bit_cnt <= 3'd0;
            spi_shift   <= 8'd0;
            spi_state   <= SPI_ST_CMD;
            spi_addr_cnt <= 2'd0;
            spi_cmd     <= 8'd0;
            spi_addr_reg <= 24'd0;
            wr_addr_reg  <= 24'd0;
            rd_addr_reg  <= 24'd0;
            miso_shift   <= 8'd0;
            miso_bit_cnt <= 3'd7;
            flash_miso_drv <= 1'b0;
        end else begin
            spi_bit_cnt <= 3'd0;
            spi_shift   <= 8'd0;
            spi_state   <= SPI_ST_CMD;
            spi_addr_cnt <= 2'd0;
            spi_cmd     <= 8'd0;
            spi_addr_reg <= 24'd0;
            wr_addr_reg  <= 24'd0;
            rd_addr_reg  <= 24'd0;
            miso_shift   <= 8'd0;
            miso_bit_cnt <= 3'd7;
            flash_miso_drv <= 1'b0;
        end
    end

    always @(posedge flash_sclk) begin
        if (!resetn)
            spi_bit_cnt <= 3'd0;
        else if (!flash_cs_n) begin
            spi_shift <= {spi_shift[6:0], flash_mosi};
            if (spi_bit_cnt == 3'd7) begin
                reg [7:0] new_byte;
                new_byte = {spi_shift[6:0], flash_mosi};
                spi_bit_cnt <= 3'd0;

                case (spi_state)
                    SPI_ST_CMD: begin
                        spi_cmd <= new_byte;
                        if ((new_byte == 8'h02) || (new_byte == 8'h03)) begin
                            spi_state <= SPI_ST_ADDR;
                            spi_addr_cnt <= 2'd0;
                            spi_addr_reg <= 24'd0;
                        end else begin
                            spi_state <= SPI_ST_IGN;
                        end
                    end

                    SPI_ST_ADDR: begin
                        spi_addr_reg <= {spi_addr_reg[15:0], new_byte};
                        if (spi_addr_cnt == 2'd2) begin
                            if (spi_cmd == 8'h02) begin
                                spi_state <= SPI_ST_WDATA;
                                wr_addr_reg <= {spi_addr_reg[15:0], new_byte};
                            end else if (spi_cmd == 8'h03) begin
                                spi_state <= SPI_ST_RDATA;
                                rd_addr_reg <= {spi_addr_reg[15:0], new_byte};
                            end else begin
                                spi_state <= SPI_ST_IGN;
                            end
                        end else begin
                            spi_addr_cnt <= spi_addr_cnt + 2'd1;
                        end
                    end

                    SPI_ST_WDATA: begin
                        flash_mem[wr_addr_reg] <= new_byte;
                        wr_addr_reg <= wr_addr_reg + 24'd1;

                        if (exp_bytes.size() == 0) begin
                            tb_fail($sformatf("Extra SPI data byte 0x%02x", new_byte));
                        end else begin
                            byte unsigned exp_b;
                            exp_b = exp_bytes.pop_front();
                            if (new_byte !== exp_b)
                                tb_fail($sformatf("SPI data mismatch got=0x%02x exp=0x%02x", new_byte, exp_b));
                            else
                                tb_pass($sformatf("SPI data match    got=0x%02x exp=0x%02x", new_byte, exp_b));
                        end
                    end

                    SPI_ST_RDATA: begin
                    end

                    default: begin
                    end
                endcase

            end else begin
                spi_bit_cnt <= spi_bit_cnt + 3'd1;
            end
        end
    end

    always @(negedge flash_sclk or negedge resetn) begin
        if (!resetn) begin
            flash_miso_drv <= 1'b0;
            miso_bit_cnt <= 3'd7;
            miso_shift <= 8'd0;
        end else if (!flash_cs_n) begin
            if (spi_state == SPI_ST_RDATA) begin
                if (miso_bit_cnt == 3'd7)
                    miso_shift <= flash_mem[rd_addr_reg];

                flash_miso_drv <= miso_shift[miso_bit_cnt];

                if (miso_bit_cnt == 3'd0) begin
                    miso_bit_cnt <= 3'd7;
                    rd_addr_reg <= rd_addr_reg + 24'd1;
                end else begin
                    miso_bit_cnt <= miso_bit_cnt - 3'd1;
                end
            end else begin
                flash_miso_drv <= 1'b0;
                miso_bit_cnt <= 3'd7;
            end
        end else begin
            flash_miso_drv <= 1'b0;
            miso_bit_cnt <= 3'd7;
        end
    end

    // ------------------------------------------------------------------
    // Completion and timeout
    // ------------------------------------------------------------------
    initial begin
        error_cnt = 0;
        pass_cnt = 0;
        wait(resetn == 1'b1);

        begin : wait_done
            integer wc;
            for (wc = 0; wc < 500000; wc = wc + 1) begin
                if (u_soc.U_SRAM.memory[DONE_FLAG_WORD_IDX] == 32'hA5A5A5A5) begin
                    tb_pass("CPU read done flag");
                    disable wait_done;
                end
                @(posedge clk);
            end
            tb_fail("Timeout waiting for CPU read done flag");
        end

        begin : check_readback
            integer k;
            reg [31:0] exp_word;
            reg [31:0] got_word;
            for (k = 0; k < SAMPLE_COUNT; k = k + 1) begin
                exp_word = {8'h00, sample_mem[k]};
                got_word = u_soc.U_SRAM.memory[RD_BUF_WORD_IDX + k];
                if (got_word !== exp_word)
                    tb_fail($sformatf("SRAM readback mismatch idx=%0d got=0x%08x exp=0x%08x", k, got_word, exp_word));
                else
                    tb_pass($sformatf("SRAM readback match    idx=%0d val=0x%08x", k, got_word));
            end
        end

        repeat (200000) @(posedge clk);
        if (exp_bytes.size() != 0) begin
            tb_fail($sformatf("Expected bytes remaining=%0d", exp_bytes.size()));
        end

        if (error_cnt == 0)
            $display("[TB] PASS");
        else
            $display("[TB] FAIL with %0d errors", error_cnt);

        $finish;
    end

endmodule
