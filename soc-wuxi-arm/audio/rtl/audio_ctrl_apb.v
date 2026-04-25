module audio_ctrl_apb #(
    parameter FIFO_DEPTH = 16
) (
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    input  wire        sample_valid,
    input  wire [23:0] sample_data,

    output wire        fifo_empty,
    output wire        fifo_full,
    output wire [15:0] fifo_level
);

localparam [11:0] ADDR_CTRL       = 12'h000;
localparam [11:0] ADDR_STATUS     = 12'h004;
localparam [11:0] ADDR_DATA       = 12'h008;
localparam [11:0] ADDR_FIFO_LEVEL = 12'h00C;

reg  fifo_en;
reg  fifo_clr_pulse;
reg  overflow_sticky;
reg  underflow_sticky;
reg  sample_valid_d;

wire wr_hit = psel & penable & pwrite;
wire rd_hit = psel & penable & ~pwrite;

wire ctrl_wr_hit   = wr_hit & (paddr == ADDR_CTRL);
wire status_wr_hit = wr_hit & (paddr == ADDR_STATUS);
wire data_rd_hit   = rd_hit & (paddr == ADDR_DATA);

wire sample_valid_rise = sample_valid & ~sample_valid_d;

wire fifo_wr_req = fifo_en & sample_valid_rise & ~fifo_clr_pulse;
wire fifo_rd_req = data_rd_hit & ~fifo_empty & ~fifo_clr_pulse;

wire [23:0] fifo_rd_data;

wire set_overflow   = fifo_wr_req & fifo_full;
wire set_underflow  = data_rd_hit & fifo_empty;
wire clr_overflow   = status_wr_hit & pwdata[2];
wire clr_underflow  = status_wr_hit & pwdata[3];

wire status_empty      = fifo_empty;
wire status_full       = fifo_full;
wire status_overflow   = overflow_sticky;
wire status_underflow  = underflow_sticky;
wire status_data_ready = (fifo_level != 16'd0);

assign pready  = 1'b1;
assign pslverr = 1'b0;

always @(posedge pclk or negedge presetn) begin
    if (!presetn)
        sample_valid_d <= 1'b0;
    else
        sample_valid_d <= sample_valid;
end

always @(posedge pclk or negedge presetn) begin
    if (!presetn)
        fifo_en <= 1'b0;
    else if (ctrl_wr_hit)
        fifo_en <= pwdata[0];
end

always @(posedge pclk or negedge presetn) begin
    if (!presetn)
        fifo_clr_pulse <= 1'b0;
    else if (ctrl_wr_hit & pwdata[1])
        fifo_clr_pulse <= 1'b1;
    else
        fifo_clr_pulse <= 1'b0;
end

always @(posedge pclk or negedge presetn) begin
    if (!presetn)
        overflow_sticky <= 1'b0;
    else
        overflow_sticky <= (overflow_sticky & ~clr_overflow) | set_overflow;
end

always @(posedge pclk or negedge presetn) begin
    if (!presetn)
        underflow_sticky <= 1'b0;
    else
        underflow_sticky <= (underflow_sticky & ~clr_underflow) | set_underflow;
end

always @(*) begin
    prdata = 32'h0000_0000;
    if (rd_hit) begin
        case (paddr)
            ADDR_CTRL: begin
                prdata[0] = fifo_en;
                prdata[1] = 1'b0;
            end
            ADDR_STATUS: begin
                prdata[0] = status_empty;
                prdata[1] = status_full;
                prdata[2] = status_overflow;
                prdata[3] = status_underflow;
                prdata[4] = status_data_ready;
            end
            ADDR_DATA: begin
                if (!fifo_empty)
                    prdata[23:0] = fifo_rd_data;
                else
                    prdata[23:0] = 24'h000000;
            end
            ADDR_FIFO_LEVEL: begin
                prdata[15:0] = fifo_level;
            end
            default: begin
                prdata = 32'h0000_0000;
            end
        endcase
    end
end

audio_fifo #(
    .DATA_WIDTH (24),
    .FIFO_DEPTH (FIFO_DEPTH)
) u_audio_fifo (
    .clk     (pclk),
    .rst_n   (presetn),
    .clr     (fifo_clr_pulse),
    .wr_en   (fifo_wr_req),
    .wr_data (sample_data),
    .rd_en   (fifo_rd_req),
    .rd_data (fifo_rd_data),
    .empty   (fifo_empty),
    .full    (fifo_full),
    .level   (fifo_level)
);

endmodule
