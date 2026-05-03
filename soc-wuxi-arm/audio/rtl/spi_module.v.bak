`default_nettype none
`timescale 1ns/1ps

module spi_module #(
    parameter CPOL              = 1'b0,
    parameter CPHA              = 1'b0,
    parameter INVERT_DATA_ORDER = 1'b0,
    parameter SPI_WORD_LEN      = 8,
    parameter SPI_HALF_DIV      = 4
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         spi_start,
    input  wire                         spi_abort,
    input  wire [SPI_WORD_LEN-1:0]      spi_tx_data,

    output reg  [SPI_WORD_LEN-1:0]      spi_rx_data,
    output reg                          spi_busy,
    output reg                          spi_done,

    output reg                          spi_sclk,
    output reg                          spi_mosi,
    input  wire                         spi_miso
);

    reg [SPI_WORD_LEN-1:0] tx_shift_reg;
    reg [15:0]            bit_idx_reg;
    reg [15:0]            div_cnt_reg;
    reg                   half_phase_reg;

    wire [15:0] first_bit_idx;
    wire [15:0] last_bit_idx;
    wire        at_last_bit;

    assign first_bit_idx = (INVERT_DATA_ORDER) ? 16'd0 : (SPI_WORD_LEN - 1);
    assign last_bit_idx  = (INVERT_DATA_ORDER) ? (SPI_WORD_LEN - 1) : 16'd0;
    assign at_last_bit   = (bit_idx_reg == last_bit_idx);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift_reg   <= {SPI_WORD_LEN{1'b0}};
            bit_idx_reg    <= 16'd0;
            div_cnt_reg    <= 16'd0;
            half_phase_reg <= 1'b0;

            spi_rx_data    <= {SPI_WORD_LEN{1'b0}};
            spi_busy       <= 1'b0;
            spi_done       <= 1'b0;
            spi_sclk       <= CPOL;
            spi_mosi       <= 1'b0;
        end else if (spi_abort) begin
            tx_shift_reg   <= {SPI_WORD_LEN{1'b0}};
            bit_idx_reg    <= 16'd0;
            div_cnt_reg    <= 16'd0;
            half_phase_reg <= 1'b0;

            spi_busy       <= 1'b0;
            spi_done       <= 1'b0;
            spi_sclk       <= CPOL;
            spi_mosi       <= 1'b0;
        end else begin
            spi_done <= 1'b0;

            if (spi_start && !spi_busy) begin
                tx_shift_reg   <= spi_tx_data;
                bit_idx_reg    <= first_bit_idx;
                div_cnt_reg    <= 16'd0;
                half_phase_reg <= 1'b0;

                spi_rx_data    <= {SPI_WORD_LEN{1'b0}};
                spi_busy       <= 1'b1;
                spi_sclk       <= CPOL;

                if (CPHA == 1'b0)
                    spi_mosi <= spi_tx_data[first_bit_idx];
                else
                    spi_mosi <= 1'b0;

            end else if (spi_busy) begin
                if (div_cnt_reg == SPI_HALF_DIV - 1) begin
                    div_cnt_reg <= 16'd0;

                    if (half_phase_reg == 1'b0) begin
                        // leading edge
                        spi_sclk       <= ~CPOL;
                        half_phase_reg <= 1'b1;

                        if (CPHA == 1'b0) begin
                            // CPHA=0: sample on leading edge
                            spi_rx_data[bit_idx_reg] <= spi_miso;
                        end else begin
                            // CPHA=1: drive data on leading edge
                            spi_mosi <= tx_shift_reg[bit_idx_reg];
                        end

                    end else begin
                        // trailing edge
                        spi_sclk       <= CPOL;
                        half_phase_reg <= 1'b0;

                        if (CPHA == 1'b0) begin
                            // CPHA=0: change data on trailing edge
                            if (at_last_bit) begin
                                spi_busy <= 1'b0;
                                spi_done <= 1'b1;
                            end else begin
                                if (INVERT_DATA_ORDER)
                                    bit_idx_reg <= bit_idx_reg + 16'd1;
                                else
                                    bit_idx_reg <= bit_idx_reg - 16'd1;

                                if (INVERT_DATA_ORDER)
                                    spi_mosi <= tx_shift_reg[bit_idx_reg + 16'd1];
                                else
                                    spi_mosi <= tx_shift_reg[bit_idx_reg - 16'd1];
                            end
                        end else begin
                            // CPHA=1: sample on trailing edge
                            spi_rx_data[bit_idx_reg] <= spi_miso;

                            if (at_last_bit) begin
                                spi_busy <= 1'b0;
                                spi_done <= 1'b1;
                            end else begin
                                if (INVERT_DATA_ORDER)
                                    bit_idx_reg <= bit_idx_reg + 16'd1;
                                else
                                    bit_idx_reg <= bit_idx_reg - 16'd1;
                            end
                        end
                    end

                end else begin
                    div_cnt_reg <= div_cnt_reg + 16'd1;
                end

            end else begin
                spi_sclk       <= CPOL;
                half_phase_reg <= 1'b0;
                div_cnt_reg    <= 16'd0;
            end
        end
    end

endmodule

`default_nettype wire