module i2s_rx_core #(
    parameter integer SAMPLE_WIDTH = 24,    // 数据宽度
    parameter integer SLOT_WIDTH   = 32,    // 每个slot的时钟周期数
    parameter         WS_POL_LEFT  = 1'b0   // WS为该电平时表示左声道
) (
    input  wire                    rst_n,
    input  wire                    i2s_sck,
    input  wire                    i2s_ws,
    input  wire                    i2s_sd,
    output reg  [SAMPLE_WIDTH-1:0] sample_data,
    output reg                     sample_valid
);

// -------------------------------------------------------
// Fix 4: shift_reg 宽度改为 SLOT_WIDTH，采集完整 slot
//        输出时再截取高 SAMPLE_WIDTH 位（MSB 先传）
// -------------------------------------------------------
reg [SLOT_WIDTH-1:0]  shift_reg;
reg [5:0]             cnt;
reg [1:0]             state;
reg [1:0]             next_state;

// WS 边沿检测寄存器
// Fix 5: 在 SCK 上升沿采样 WS，用于检测跳变
reg ws_d1;
wire ws_rise =  i2s_ws & ~ws_d1;   // WS 上升沿
wire ws_fall = ~i2s_ws &  ws_d1;   // WS 下降沿

// 根据极性参数判断"进入左声道"和"进入右声道"的 WS 边沿
// WS_POL_LEFT=0 意味着 WS 低电平为左声道：
//   WS 下降沿 → 进入左声道，WS 上升沿 → 进入右声道
wire enter_left  = (WS_POL_LEFT == 1'b0) ? ws_fall : ws_rise;
wire enter_right = (WS_POL_LEFT == 1'b0) ? ws_rise : ws_fall;

localparam IDLE = 2'b00,
           LEFT = 2'b01,
           RIGT = 2'b10;

// -------------------------------------------------------
// WS 延迟寄存器（与 state 同步更新）
// -------------------------------------------------------
always @(posedge i2s_sck or negedge rst_n) begin
    if (!rst_n)
        ws_d1 <= 1'b0;
    else
        ws_d1 <= i2s_ws;
end

// -------------------------------------------------------
// 状态寄存器
// -------------------------------------------------------
always @(posedge i2s_sck or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// -------------------------------------------------------
// Fix 3 + Fix 5: 次态逻辑
//   IDLE：等待 WS 边沿，而非电平，避免上电不定态
//   LEFT/RIGT：用 cnt == SLOT_WIDTH-1 判断 slot 结束
//              同时检测提前到来的 WS 边沿（容错）
// -------------------------------------------------------
always @(*) begin
    case (state)
        IDLE: begin
            if      (enter_left)  next_state = LEFT;
            else if (enter_right) next_state = RIGT;
            else                  next_state = IDLE;
        end
        LEFT: begin
            // Fix 1: SLOT_WIDTH-1 而非 SLOT_WIDTH
            if (cnt == SLOT_WIDTH - 1)
                next_state = RIGT;
            else if (enter_right)       // 容错：WS 边沿提前
                next_state = RIGT;
            else
                next_state = LEFT;
        end
        RIGT: begin
            if (cnt == SLOT_WIDTH - 1)
                next_state = LEFT;
            else if (enter_left)        // 容错：WS 边沿提前
                next_state = LEFT;
            else
                next_state = RIGT;
        end
        default:
            next_state = IDLE;
    endcase
end

// -------------------------------------------------------
// 数据路径
// -------------------------------------------------------
always @(posedge i2s_sck or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg    <= 0;
        sample_data  <= 0;
        sample_valid <= 1'b0;
        cnt          <= 0;
    end else begin
        // 默认拉低 valid（单周期脉冲）
        sample_valid <= 1'b0;

        case (state)
            IDLE: begin
                cnt       <= 0;
                shift_reg <= 0;
            end

            LEFT: begin
                if (cnt == SLOT_WIDTH - 1) begin
                    // Fix 1: 最后一拍：先移入当前位，再锁存输出
                    shift_reg    <= {shift_reg[SLOT_WIDTH-2:0], i2s_sd};
                    // Fix 4: 取高 SAMPLE_WIDTH 位（I2S MSB 先传）
                    sample_data  <= {shift_reg[SLOT_WIDTH-2:0], i2s_sd}
                                    [SLOT_WIDTH-1 -: SAMPLE_WIDTH];
                    sample_valid <= 1'b1;
                    cnt          <= 0;
                end else begin
                    shift_reg <= {shift_reg[SLOT_WIDTH-2:0], i2s_sd};
                    cnt       <= cnt + 1;
                end
            end

            RIGT: begin
                // Fix 2: 右声道不接收数据，但不清零 shift_reg
                //        清零会破坏紧接其后左声道的首拍内容（无害但不规范）
                //        此处复位 cnt 即可
                if (cnt == SLOT_WIDTH - 1) begin
                    cnt <= 0;
                end else begin
                    cnt <= cnt + 1;
                end
                // 右声道数据直接丢弃（单声道模式）
            end

            default: begin
                shift_reg <= 0;
                cnt       <= 0;
            end
        endcase
    end
end

endmodule