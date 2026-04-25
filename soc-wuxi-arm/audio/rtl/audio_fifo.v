module audio_fifo #(
    parameter integer DATA_WIDTH = 24,
    parameter integer FIFO_DEPTH = 16
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   clr,

    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,

    input  wire                   rd_en,
    output reg  [DATA_WIDTH-1:0]  rd_data,

    output wire                   empty,
    output wire                   full,
    output wire [15:0]            level
);

function integer f_clog2;
    input integer value;
    integer tmp;
    begin
        tmp = value - 1;
        for (f_clog2 = 0; tmp > 0; f_clog2 = f_clog2 + 1)
            tmp = tmp >> 1;
        if (f_clog2 == 0)
            f_clog2 = 1;
    end
endfunction

localparam integer ADDR_WIDTH = f_clog2(FIFO_DEPTH);

reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
reg [ADDR_WIDTH-1:0] wr_ptr;
reg [ADDR_WIDTH-1:0] rd_ptr;
reg [15:0]           item_cnt;

wire wr_allow = wr_en & ~full;
wire rd_allow = rd_en & ~empty;

function [ADDR_WIDTH-1:0] ptr_inc;
    input [ADDR_WIDTH-1:0] ptr;
    begin
        if (ptr == FIFO_DEPTH - 1)
            ptr_inc = {ADDR_WIDTH{1'b0}};
        else
            ptr_inc = ptr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
    end
endfunction

assign empty = (item_cnt == 16'd0);
assign full  = (item_cnt == FIFO_DEPTH[15:0]);
assign level = item_cnt;

always @(*) begin
    if (empty)
        rd_data = {DATA_WIDTH{1'b0}};
    else
        rd_data = mem[rd_ptr];
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr   <= {ADDR_WIDTH{1'b0}};
        rd_ptr   <= {ADDR_WIDTH{1'b0}};
        item_cnt <= 16'd0;
    end else if (clr) begin
        wr_ptr   <= {ADDR_WIDTH{1'b0}};
        rd_ptr   <= {ADDR_WIDTH{1'b0}};
        item_cnt <= 16'd0;
    end else begin
        if (wr_allow) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr      <= ptr_inc(wr_ptr);
        end

        if (rd_allow)
            rd_ptr <= ptr_inc(rd_ptr);

        case ({wr_allow, rd_allow})
            2'b10: item_cnt <= item_cnt + 16'd1;
            2'b01: item_cnt <= item_cnt - 16'd1;
            default: item_cnt <= item_cnt;
        endcase
    end
end

endmodule
