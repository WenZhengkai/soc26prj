module i2s_rx_core #(
    parameter integer SAMPLE_WIDTH = 24,
    parameter integer SLOT_WIDTH   = 32,
    parameter         WS_POL_LEFT  = 1'b0
) (
    input  wire                    rst_n,
    input  wire                    i2s_sck,
    input  wire                    i2s_ws,
    input  wire                    i2s_sd,
    input  wire                    rx_en,
    output reg  [SAMPLE_WIDTH-1:0] sample_data,
    output reg                     sample_valid
);

localparam integer BIT_CNT_W = 6;

reg                     ws_d;
reg [SAMPLE_WIDTH-1:0]  shift_reg;
reg [BIT_CNT_W-1:0]     bit_cnt;
reg                     left_active;

always @(posedge i2s_sck or negedge rst_n) begin
    if (!rst_n) begin
        ws_d        <= 1'b0;
        shift_reg   <= {SAMPLE_WIDTH{1'b0}};
        bit_cnt     <= {BIT_CNT_W{1'b0}};
        left_active <= 1'b0;
        sample_data <= {SAMPLE_WIDTH{1'b0}};
        sample_valid<= 1'b0;
    end else begin
        sample_valid <= 1'b0;
        ws_d         <= i2s_ws;

        if (!rx_en) begin
            shift_reg    <= {SAMPLE_WIDTH{1'b0}};
            bit_cnt      <= {BIT_CNT_W{1'b0}};
            left_active  <= 1'b0;
        end else begin
            if (ws_d != i2s_ws) begin
                bit_cnt      <= {BIT_CNT_W{1'b0}};
                shift_reg    <= {SAMPLE_WIDTH{1'b0}};

                if (i2s_ws == WS_POL_LEFT) begin
                    left_active <= 1'b1;
                end else begin
                    left_active <= 1'b0;
                end
            end else if (left_active) begin
                if (bit_cnt < SLOT_WIDTH-1) begin
                    bit_cnt <= bit_cnt + 1'b1;
                end

                if ((bit_cnt >= 1) && (bit_cnt <= SAMPLE_WIDTH)) begin
                    shift_reg    <= {shift_reg[SAMPLE_WIDTH-2:0], i2s_sd};

                    if (bit_cnt == SAMPLE_WIDTH) begin
                        sample_data  <= {shift_reg[SAMPLE_WIDTH-2:0], i2s_sd};
                        sample_valid <= 1'b1;
                    end
                end
            end
        end
    end
end

endmodule
