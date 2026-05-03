`default_nettype none
`timescale 1ns/1ps

module spi_flash_apb_ctrl (
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

    output reg         flash_cs_n,
    output wire        flash_sclk,
    output wire        flash_mosi,
    input  wire        flash_miso
);

    // ============================================================
    // Basic parameters
    // ============================================================

    parameter SPI_HALF_DIV = 4;
    parameter POLL_TIMEOUT = 32'd1000000;

    localparam [7:0] CMD_WREN = 8'h06;
    localparam [7:0] CMD_RDSR = 8'h05;
    localparam [7:0] CMD_PP   = 8'h02;
    localparam [7:0] CMD_SE   = 8'h20;
    localparam [7:0] CMD_READ = 8'h03;

    localparam [23:0] SECTOR_SIZE = 24'h001000;

    // ============================================================
    // APB register map
    // ============================================================

    localparam [11:0] REG_START_ADDR = 12'h000;
    localparam [11:0] REG_BYTE_LEN   = 12'h004;
    localparam [11:0] REG_CTRL       = 12'h008;
    localparam [11:0] REG_STATUS     = 12'h00C;
    localparam [11:0] REG_WDATA      = 12'h010;
    localparam [11:0] REG_RDATA      = 12'h014;
    localparam [11:0] REG_DEBUG_CNT  = 12'h018;

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    wire apb_write = psel & penable & pwrite;
    wire apb_read  = psel & penable & (~pwrite);

    wire wr_start_addr = apb_write & (paddr == REG_START_ADDR);
    wire wr_byte_len   = apb_write & (paddr == REG_BYTE_LEN);
    wire wr_ctrl       = apb_write & (paddr == REG_CTRL);
    wire wr_status     = apb_write & (paddr == REG_STATUS);
    wire wr_wdata      = apb_write & (paddr == REG_WDATA);
    wire rd_rdata      = apb_read & (paddr == REG_RDATA);

    wire start_wr_req = wr_ctrl & pwdata[0];
    wire start_rd_req = wr_ctrl & pwdata[1];
    wire abort_req    = wr_ctrl & pwdata[2];
    wire clr_done_req = wr_ctrl & pwdata[3];

    wire start_any_req = start_wr_req | start_rd_req;

    // ============================================================
    // FSM states
    // ============================================================

    localparam [4:0] ST_IDLE             = 5'd0;
    localparam [4:0] ST_ERASE_CHECK      = 5'd1;

    localparam [4:0] ST_WREN_START       = 5'd2;
    localparam [4:0] ST_WREN_WAIT        = 5'd3;

    localparam [4:0] ST_ERASE_CMD_START  = 5'd4;
    localparam [4:0] ST_ERASE_CMD_WAIT   = 5'd5;

    localparam [4:0] ST_POLL_CMD_START   = 5'd6;
    localparam [4:0] ST_POLL_CMD_WAIT    = 5'd7;
    localparam [4:0] ST_POLL_DUMMY_START = 5'd8;
    localparam [4:0] ST_POLL_DUMMY_WAIT  = 5'd9;
    localparam [4:0] ST_POLL_CHECK       = 5'd10;

    localparam [4:0] ST_PAGE_PREP        = 5'd11;

    localparam [4:0] ST_PP_CMD_START     = 5'd12;
    localparam [4:0] ST_PP_CMD_WAIT      = 5'd13;

    localparam [4:0] ST_PP_DATA_NEED     = 5'd14;
    localparam [4:0] ST_PP_DATA_START    = 5'd15;
    localparam [4:0] ST_PP_DATA_WAIT     = 5'd16;

    localparam [4:0] ST_RD_CMD_START     = 5'd20;
    localparam [4:0] ST_RD_CMD_WAIT      = 5'd21;
    localparam [4:0] ST_RD_ADDR_START    = 5'd22;
    localparam [4:0] ST_RD_ADDR_WAIT     = 5'd23;
    localparam [4:0] ST_RD_DATA_START    = 5'd24;
    localparam [4:0] ST_RD_DATA_WAIT     = 5'd25;

    localparam [4:0] ST_FINISH           = 5'd17;
    localparam [4:0] ST_ERROR            = 5'd18;
    localparam [4:0] ST_ABORT            = 5'd19;

    localparam TARGET_ERASE   = 1'b0;
    localparam TARGET_PROGRAM = 1'b1;

    // ============================================================
    // Registers
    // ============================================================

    reg [4:0] state;
    reg [4:0] next_state;

    reg [23:0] start_addr_reg;
    reg [23:0] byte_len_reg;

    reg        busy_reg;
    reg        done_reg;
    reg        err_reg;
    reg        overflow_reg;
    reg        underflow_reg;

    reg [23:0] debug_cnt_reg;

    reg [23:0] curr_addr_reg;
    reg [23:0] bytes_left_reg;
    reg [23:0] total_len_reg;

    reg [23:0] erase_addr_reg;
    reg [23:0] erase_last_addr_reg;

    reg        wren_target_reg;
    reg        poll_target_reg;

    reg [1:0]  cmd_idx_reg;
    reg [8:0]  page_chunk_left_reg;

    reg [31:0] poll_count_reg;
    reg [7:0]  last_status_reg;

    reg [31:0] wbuf_reg;
    reg        wbuf_valid_reg;
    reg [1:0]  wbuf_byte_idx_reg;

    reg        op_is_read_reg;

    reg [31:0] rbuf_reg;
    reg        rbuf_valid_reg;
    reg [1:0]  rbuf_byte_idx_reg;

    // ============================================================
    // SPI module connection
    // ============================================================

    reg        spi_start_reg;
    reg [7:0]  spi_tx_data_reg;
    wire [7:0] spi_rx_data_wire;
    wire       spi_busy_wire;
    wire       spi_done_wire;

    wire       spi_abort_wire;

    assign spi_abort_wire = abort_req & busy_reg;

    spi_module #(
        .CPOL              (1'b0),
        .CPHA              (1'b0),
        .INVERT_DATA_ORDER (1'b0),
        .SPI_WORD_LEN      (8),
        .SPI_HALF_DIV      (SPI_HALF_DIV)
    ) u_spi_module (
        .clk         (pclk),
        .rst_n       (presetn),

        .spi_start   (spi_start_reg),
        .spi_abort   (spi_abort_wire),
        .spi_tx_data (spi_tx_data_reg),

        .spi_rx_data (spi_rx_data_wire),
        .spi_busy    (spi_busy_wire),
        .spi_done    (spi_done_wire),

        .spi_sclk    (flash_sclk),
        .spi_mosi    (flash_mosi),
        .spi_miso    (flash_miso)
    );

    // ============================================================
    // Helper functions
    // ============================================================

    function [23:0] align_sector;
        input [23:0] addr;
        begin
            align_sector = {addr[23:12], 12'b0};
        end
    endfunction

    function [8:0] calc_page_chunk;
        input [23:0] addr;
        input [23:0] bytes_left;
        reg   [8:0]  page_room;
        begin
            page_room = 9'd256 - {1'b0, addr[7:0]};

            if ({15'd0, page_room} > bytes_left)
                calc_page_chunk = {1'b0, bytes_left[7:0]};
            else
                calc_page_chunk = page_room;
        end
    endfunction

    wire [24:0] end_addr_calc;
    wire        addr_overflow;
    wire        align_error;

    assign end_addr_calc =
        {1'b0, start_addr_reg} + {1'b0, byte_len_reg} - 25'd1;

    assign addr_overflow =
        (byte_len_reg != 24'd0) && end_addr_calc[24];

    assign align_error =
        (start_addr_reg[1:0] != 2'b00) ||
        (byte_len_reg[1:0]   != 2'b00);

    wire wdata_ready_wire;
    wire rdata_valid_wire;

    assign wdata_ready_wire =
        (state == ST_PP_DATA_NEED) &&
        busy_reg &&
        !op_is_read_reg &&
        !wbuf_valid_reg &&
        (bytes_left_reg != 24'd0) &&
        !err_reg;

    assign rdata_valid_wire = op_is_read_reg && rbuf_valid_reg;

    // ============================================================
    // APB read mux
    // ============================================================

    always @(*) begin
        prdata = 32'd0;

        if (apb_read) begin
            case (paddr)
                REG_START_ADDR: begin
                    prdata = {8'd0, start_addr_reg};
                end

                REG_BYTE_LEN: begin
                    prdata = {8'd0, byte_len_reg};
                end

                REG_CTRL: begin
                    prdata = 32'd0;
                end

                REG_STATUS: begin
                    prdata = {
                        25'd0,
                        underflow_reg,
                        overflow_reg,
                        rdata_valid_wire,
                        wdata_ready_wire,
                        err_reg,
                        done_reg,
                        busy_reg
                    };
                end

                REG_RDATA: begin
                    if (rdata_valid_wire)
                        prdata = rbuf_reg;
                    else
                        prdata = 32'd0;
                end

                REG_DEBUG_CNT: begin
                    prdata = {8'd0, debug_cnt_reg};
                end

                default: begin
                    prdata = 32'd0;
                end
            endcase
        end
    end

    // ============================================================
    // FSM segment 1: state register
    // ============================================================

    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // ============================================================
    // FSM segment 2: next-state logic
    // ============================================================

    always @(*) begin
        next_state = state;

        if (abort_req && busy_reg) begin
            next_state = ST_ABORT;
        end else if (err_reg && busy_reg) begin
            next_state = ST_ERROR;
        end else begin
            case (state)

                ST_IDLE: begin
                    if (start_wr_req && !busy_reg) begin
                        if ((byte_len_reg != 24'd0) &&
                            !addr_overflow &&
                            !align_error)
                            next_state = ST_ERASE_CHECK;
                        else
                            next_state = ST_IDLE;
                    end else if (start_rd_req && !busy_reg) begin
                        if ((byte_len_reg != 24'd0) &&
                            !addr_overflow &&
                            !align_error)
                            next_state = ST_RD_CMD_START;
                        else
                            next_state = ST_IDLE;
                    end
                end

                ST_ERASE_CHECK: begin
                    if (erase_addr_reg <= erase_last_addr_reg)
                        next_state = ST_WREN_START;
                    else
                        next_state = ST_PAGE_PREP;
                end

                ST_WREN_START: begin
                    next_state = ST_WREN_WAIT;
                end

                ST_WREN_WAIT: begin
                    if (spi_done_wire) begin
                        if (wren_target_reg == TARGET_ERASE)
                            next_state = ST_ERASE_CMD_START;
                        else
                            next_state = ST_PP_CMD_START;
                    end
                end

                ST_ERASE_CMD_START: begin
                    next_state = ST_ERASE_CMD_WAIT;
                end

                ST_ERASE_CMD_WAIT: begin
                    if (spi_done_wire) begin
                        if (cmd_idx_reg == 2'd3)
                            next_state = ST_POLL_CMD_START;
                        else
                            next_state = ST_ERASE_CMD_START;
                    end
                end

                ST_POLL_CMD_START: begin
                    next_state = ST_POLL_CMD_WAIT;
                end

                ST_POLL_CMD_WAIT: begin
                    if (spi_done_wire)
                        next_state = ST_POLL_DUMMY_START;
                end

                ST_POLL_DUMMY_START: begin
                    next_state = ST_POLL_DUMMY_WAIT;
                end

                ST_POLL_DUMMY_WAIT: begin
                    if (spi_done_wire)
                        next_state = ST_POLL_CHECK;
                end

                ST_POLL_CHECK: begin
                    if (last_status_reg[0]) begin
                        if (poll_count_reg >= POLL_TIMEOUT)
                            next_state = ST_ERROR;
                        else
                            next_state = ST_POLL_CMD_START;
                    end else begin
                        if (poll_target_reg == TARGET_ERASE) begin
                            if (erase_addr_reg >= erase_last_addr_reg)
                                next_state = ST_PAGE_PREP;
                            else
                                next_state = ST_ERASE_CHECK;
                        end else begin
                            next_state = ST_PAGE_PREP;
                        end
                    end
                end

                ST_PAGE_PREP: begin
                    if (bytes_left_reg == 24'd0)
                        next_state = ST_FINISH;
                    else
                        next_state = ST_WREN_START;
                end

                ST_PP_CMD_START: begin
                    next_state = ST_PP_CMD_WAIT;
                end

                ST_PP_CMD_WAIT: begin
                    if (spi_done_wire) begin
                        if (cmd_idx_reg == 2'd3)
                            next_state = ST_PP_DATA_NEED;
                        else
                            next_state = ST_PP_CMD_START;
                    end
                end

                ST_PP_DATA_NEED: begin
                    if (wbuf_valid_reg)
                        next_state = ST_PP_DATA_START;
                end

                ST_PP_DATA_START: begin
                    next_state = ST_PP_DATA_WAIT;
                end

                ST_PP_DATA_WAIT: begin
                    if (spi_done_wire) begin
                        if (page_chunk_left_reg == 9'd1)
                            next_state = ST_POLL_CMD_START;
                        else if (wbuf_byte_idx_reg == 2'd3)
                            next_state = ST_PP_DATA_NEED;
                        else
                            next_state = ST_PP_DATA_START;
                    end
                end

                ST_RD_CMD_START: begin
                    next_state = ST_RD_CMD_WAIT;
                end

                ST_RD_CMD_WAIT: begin
                    if (spi_done_wire)
                        next_state = ST_RD_ADDR_START;
                end

                ST_RD_ADDR_START: begin
                    next_state = ST_RD_ADDR_WAIT;
                end

                ST_RD_ADDR_WAIT: begin
                    if (spi_done_wire) begin
                        if (cmd_idx_reg == 2'd2)
                            next_state = ST_RD_DATA_START;
                        else
                            next_state = ST_RD_ADDR_START;
                    end
                end

                ST_RD_DATA_START: begin
                    if ((bytes_left_reg == 24'd0) && !rbuf_valid_reg)
                        next_state = ST_FINISH;
                    else if (!rbuf_valid_reg && (bytes_left_reg != 24'd0))
                        next_state = ST_RD_DATA_WAIT;
                    else
                        next_state = ST_RD_DATA_START;
                end

                ST_RD_DATA_WAIT: begin
                    if (spi_done_wire) begin
                        if (bytes_left_reg == 24'd1)
                            next_state = ST_FINISH;
                        else
                            next_state = ST_RD_DATA_START;
                    end
                end

                ST_FINISH: begin
                    next_state = ST_IDLE;
                end

                ST_ERROR: begin
                    next_state = ST_IDLE;
                end

                ST_ABORT: begin
                    next_state = ST_IDLE;
                end

                default: begin
                    next_state = ST_ERROR;
                end

            endcase
        end
    end

    // ============================================================
    // FSM segment 3: output and data registers
    // ============================================================

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            start_addr_reg      <= 24'd0;
            byte_len_reg        <= 24'd0;

            busy_reg            <= 1'b0;
            done_reg            <= 1'b0;
            err_reg             <= 1'b0;
            overflow_reg        <= 1'b0;
            underflow_reg       <= 1'b0;

            debug_cnt_reg       <= 24'd0;

            curr_addr_reg       <= 24'd0;
            bytes_left_reg      <= 24'd0;
            total_len_reg       <= 24'd0;

            erase_addr_reg      <= 24'd0;
            erase_last_addr_reg <= 24'd0;

            wren_target_reg     <= TARGET_ERASE;
            poll_target_reg     <= TARGET_ERASE;

            cmd_idx_reg         <= 2'd0;
            page_chunk_left_reg <= 9'd0;

            poll_count_reg      <= 32'd0;
            last_status_reg     <= 8'd0;

            wbuf_reg            <= 32'd0;
            wbuf_valid_reg      <= 1'b0;
            wbuf_byte_idx_reg   <= 2'd0;

            op_is_read_reg      <= 1'b0;

            rbuf_reg            <= 32'd0;
            rbuf_valid_reg      <= 1'b0;
            rbuf_byte_idx_reg   <= 2'd0;

            flash_cs_n          <= 1'b1;

            spi_start_reg       <= 1'b0;
            spi_tx_data_reg     <= 8'd0;

        end else begin
            spi_start_reg <= 1'b0;

            // ----------------------------------------------------
            // APB write registers
            // ----------------------------------------------------

            if (wr_start_addr) begin
                if (!busy_reg)
                    start_addr_reg <= pwdata[23:0];
                else
                    err_reg <= 1'b1;
            end

            if (wr_byte_len) begin
                if (!busy_reg)
                    byte_len_reg <= pwdata[23:0];
                else
                    err_reg <= 1'b1;
            end

            if (wr_status) begin
                if (pwdata[1])
                    done_reg <= 1'b0;

                if (pwdata[2])
                    err_reg <= 1'b0;

                if (pwdata[5])
                    overflow_reg <= 1'b0;

                if (pwdata[6])
                    underflow_reg <= 1'b0;
            end

            if (clr_done_req)
                done_reg <= 1'b0;

            if (start_any_req && busy_reg)
                err_reg <= 1'b1;

            if (start_wr_req && start_rd_req)
                err_reg <= 1'b1;

            if (wr_wdata) begin
                if (wdata_ready_wire) begin
                    wbuf_reg          <= pwdata;
                    wbuf_valid_reg    <= 1'b1;
                    wbuf_byte_idx_reg <= 2'd0;
                end else begin
                    err_reg <= 1'b1;

                    if ((total_len_reg != 24'd0) &&
                        (debug_cnt_reg >= total_len_reg))
                        overflow_reg <= 1'b1;
                end
            end

            if (rd_rdata) begin
                if (rdata_valid_wire) begin
                    rbuf_valid_reg    <= 1'b0;
                    rbuf_byte_idx_reg <= 2'd0;
                    rbuf_reg          <= 32'd0;
                end else begin
                    underflow_reg <= 1'b1;
                end
            end

            // ----------------------------------------------------
            // Global abort
            // ----------------------------------------------------

            if (abort_req && busy_reg) begin
                flash_cs_n          <= 1'b1;
                busy_reg            <= 1'b0;
                done_reg            <= 1'b0;
                err_reg             <= 1'b1;
                op_is_read_reg      <= 1'b0;

                wbuf_valid_reg      <= 1'b0;
                page_chunk_left_reg <= 9'd0;
                rbuf_valid_reg      <= 1'b0;
                rbuf_byte_idx_reg   <= 2'd0;
                rbuf_reg            <= 32'd0;

            end else begin
                case (state)

                    ST_IDLE: begin
                        flash_cs_n <= 1'b1;

                        if (start_wr_req && !busy_reg) begin
                            done_reg      <= 1'b0;
                            err_reg       <= 1'b0;
                            overflow_reg  <= 1'b0;
                            underflow_reg <= 1'b0;
                            debug_cnt_reg <= 24'd0;

                            if (byte_len_reg == 24'd0) begin
                                done_reg <= 1'b1;
                            end else if (addr_overflow || align_error) begin
                                err_reg <= 1'b1;
                            end else begin
                                busy_reg            <= 1'b1;
                                op_is_read_reg      <= 1'b0;

                                curr_addr_reg       <= start_addr_reg;
                                bytes_left_reg      <= byte_len_reg;
                                total_len_reg       <= byte_len_reg;

                                erase_addr_reg      <= align_sector(start_addr_reg);
                                erase_last_addr_reg <= align_sector(end_addr_calc[23:0]);

                                wbuf_reg            <= 32'd0;
                                wbuf_valid_reg      <= 1'b0;
                                wbuf_byte_idx_reg   <= 2'd0;

                                rbuf_reg            <= 32'd0;
                                rbuf_valid_reg      <= 1'b0;
                                rbuf_byte_idx_reg   <= 2'd0;

                                wren_target_reg     <= TARGET_ERASE;
                                poll_target_reg     <= TARGET_ERASE;

                                cmd_idx_reg         <= 2'd0;
                                poll_count_reg      <= 32'd0;
                                last_status_reg     <= 8'd0;
                            end
                        end else if (start_rd_req && !busy_reg) begin
                            done_reg      <= 1'b0;
                            err_reg       <= 1'b0;
                            overflow_reg  <= 1'b0;
                            underflow_reg <= 1'b0;
                            debug_cnt_reg <= 24'd0;

                            if (byte_len_reg == 24'd0) begin
                                done_reg <= 1'b1;
                            end else if (addr_overflow || align_error) begin
                                err_reg <= 1'b1;
                            end else begin
                                busy_reg            <= 1'b1;
                                op_is_read_reg      <= 1'b1;

                                curr_addr_reg       <= start_addr_reg;
                                bytes_left_reg      <= byte_len_reg;
                                total_len_reg       <= byte_len_reg;

                                wbuf_reg            <= 32'd0;
                                wbuf_valid_reg      <= 1'b0;
                                wbuf_byte_idx_reg   <= 2'd0;

                                rbuf_reg            <= 32'd0;
                                rbuf_valid_reg      <= 1'b0;
                                rbuf_byte_idx_reg   <= 2'd0;

                                cmd_idx_reg         <= 2'd0;
                                poll_count_reg      <= 32'd0;
                                last_status_reg     <= 8'd0;
                            end
                        end
                    end

                    ST_ERASE_CHECK: begin
                        flash_cs_n      <= 1'b1;
                        cmd_idx_reg     <= 2'd0;
                        wren_target_reg <= TARGET_ERASE;
                    end

                    ST_WREN_START: begin
                        flash_cs_n       <= 1'b0;
                        spi_tx_data_reg  <= CMD_WREN;
                        spi_start_reg    <= 1'b1;
                    end

                    ST_WREN_WAIT: begin
                        if (spi_done_wire) begin
                            flash_cs_n  <= 1'b1;
                            cmd_idx_reg <= 2'd0;
                        end
                    end

                    ST_ERASE_CMD_START: begin
                        flash_cs_n <= 1'b0;

                        case (cmd_idx_reg)
                            2'd0: spi_tx_data_reg <= CMD_SE;
                            2'd1: spi_tx_data_reg <= erase_addr_reg[23:16];
                            2'd2: spi_tx_data_reg <= erase_addr_reg[15:8];
                            2'd3: spi_tx_data_reg <= erase_addr_reg[7:0];
                            default: spi_tx_data_reg <= 8'h00;
                        endcase

                        spi_start_reg <= 1'b1;
                    end

                    ST_ERASE_CMD_WAIT: begin
                        if (spi_done_wire) begin
                            if (cmd_idx_reg == 2'd3) begin
                                flash_cs_n      <= 1'b1;
                                cmd_idx_reg     <= 2'd0;
                                poll_target_reg <= TARGET_ERASE;
                                poll_count_reg  <= 32'd0;
                            end else begin
                                cmd_idx_reg <= cmd_idx_reg + 2'd1;
                            end
                        end
                    end

                    ST_POLL_CMD_START: begin
                        flash_cs_n      <= 1'b0;
                        spi_tx_data_reg <= CMD_RDSR;
                        spi_start_reg   <= 1'b1;
                    end

                    ST_POLL_CMD_WAIT: begin
                    end

                    ST_POLL_DUMMY_START: begin
                        spi_tx_data_reg <= 8'h00;
                        spi_start_reg   <= 1'b1;
                    end

                    ST_POLL_DUMMY_WAIT: begin
                        if (spi_done_wire) begin
                            last_status_reg <= spi_rx_data_wire;
                            flash_cs_n      <= 1'b1;
                        end
                    end

                    ST_POLL_CHECK: begin
                        if (last_status_reg[0]) begin
                            poll_count_reg <= poll_count_reg + 32'd1;
                        end else begin
                            poll_count_reg <= 32'd0;

                            if (poll_target_reg == TARGET_ERASE) begin
                                if (erase_addr_reg < erase_last_addr_reg)
                                    erase_addr_reg <= erase_addr_reg + SECTOR_SIZE;
                            end
                        end
                    end

                    ST_PAGE_PREP: begin
                        flash_cs_n         <= 1'b1;
                        cmd_idx_reg        <= 2'd0;

                        wren_target_reg    <= TARGET_PROGRAM;
                        poll_target_reg    <= TARGET_PROGRAM;

                        wbuf_valid_reg     <= 1'b0;
                        wbuf_byte_idx_reg  <= 2'd0;

                        if (bytes_left_reg != 24'd0)
                            page_chunk_left_reg <= calc_page_chunk(curr_addr_reg, bytes_left_reg);
                    end

                    ST_PP_CMD_START: begin
                        flash_cs_n <= 1'b0;

                        case (cmd_idx_reg)
                            2'd0: spi_tx_data_reg <= CMD_PP;
                            2'd1: spi_tx_data_reg <= curr_addr_reg[23:16];
                            2'd2: spi_tx_data_reg <= curr_addr_reg[15:8];
                            2'd3: spi_tx_data_reg <= curr_addr_reg[7:0];
                            default: spi_tx_data_reg <= 8'h00;
                        endcase

                        spi_start_reg <= 1'b1;
                    end

                    ST_PP_CMD_WAIT: begin
                        if (spi_done_wire) begin
                            if (cmd_idx_reg == 2'd3)
                                cmd_idx_reg <= 2'd0;
                            else
                                cmd_idx_reg <= cmd_idx_reg + 2'd1;
                        end
                    end

                    ST_PP_DATA_NEED: begin
                        flash_cs_n <= 1'b0;
                    end

                    ST_PP_DATA_START: begin
                        flash_cs_n <= 1'b0;

                        case (wbuf_byte_idx_reg)
                            2'd0: spi_tx_data_reg <= wbuf_reg[7:0];
                            2'd1: spi_tx_data_reg <= wbuf_reg[15:8];
                            2'd2: spi_tx_data_reg <= wbuf_reg[23:16];
                            2'd3: spi_tx_data_reg <= wbuf_reg[31:24];
                            default: spi_tx_data_reg <= 8'h00;
                        endcase

                        spi_start_reg <= 1'b1;
                    end

                    ST_PP_DATA_WAIT: begin
                        if (spi_done_wire) begin
                            curr_addr_reg       <= curr_addr_reg + 24'd1;
                            bytes_left_reg      <= bytes_left_reg - 24'd1;
                            debug_cnt_reg       <= debug_cnt_reg + 24'd1;
                            page_chunk_left_reg <= page_chunk_left_reg - 9'd1;

                            if (wbuf_byte_idx_reg == 2'd3) begin
                                wbuf_valid_reg    <= 1'b0;
                                wbuf_byte_idx_reg <= 2'd0;
                            end else begin
                                wbuf_byte_idx_reg <= wbuf_byte_idx_reg + 2'd1;
                            end

                            if (page_chunk_left_reg == 9'd1) begin
                                flash_cs_n      <= 1'b1;
                                poll_target_reg <= TARGET_PROGRAM;
                                poll_count_reg  <= 32'd0;
                            end
                        end
                    end

                    ST_RD_CMD_START: begin
                        flash_cs_n      <= 1'b0;
                        spi_tx_data_reg <= CMD_READ;
                        spi_start_reg   <= 1'b1;
                    end

                    ST_RD_CMD_WAIT: begin
                        if (spi_done_wire)
                            cmd_idx_reg <= 2'd0;
                    end

                    ST_RD_ADDR_START: begin
                        flash_cs_n <= 1'b0;

                        case (cmd_idx_reg)
                            2'd0: spi_tx_data_reg <= curr_addr_reg[23:16];
                            2'd1: spi_tx_data_reg <= curr_addr_reg[15:8];
                            2'd2: spi_tx_data_reg <= curr_addr_reg[7:0];
                            default: spi_tx_data_reg <= 8'h00;
                        endcase

                        spi_start_reg <= 1'b1;
                    end

                    ST_RD_ADDR_WAIT: begin
                        if (spi_done_wire) begin
                            if (cmd_idx_reg == 2'd2)
                                cmd_idx_reg <= 2'd0;
                            else
                                cmd_idx_reg <= cmd_idx_reg + 2'd1;
                        end
                    end

                    ST_RD_DATA_START: begin
                        flash_cs_n <= 1'b0;

                        if (!rbuf_valid_reg && (bytes_left_reg != 24'd0)) begin
                            spi_tx_data_reg <= 8'h00;
                            spi_start_reg   <= 1'b1;
                        end
                    end

                    ST_RD_DATA_WAIT: begin
                        if (spi_done_wire) begin
                            if (rbuf_byte_idx_reg == 2'd0)
                                rbuf_reg <= 32'd0;

                            case (rbuf_byte_idx_reg)
                                2'd0: rbuf_reg[7:0]   <= spi_rx_data_wire;
                                2'd1: rbuf_reg[15:8]  <= spi_rx_data_wire;
                                2'd2: rbuf_reg[23:16] <= spi_rx_data_wire;
                                2'd3: rbuf_reg[31:24] <= spi_rx_data_wire;
                                default: rbuf_reg[7:0] <= spi_rx_data_wire;
                            endcase

                            curr_addr_reg  <= curr_addr_reg + 24'd1;
                            bytes_left_reg <= bytes_left_reg - 24'd1;
                            debug_cnt_reg  <= debug_cnt_reg + 24'd1;

                            if (bytes_left_reg == 24'd1) begin
                                case (rbuf_byte_idx_reg)
                                    2'd0: rbuf_reg[31:8]  <= 24'd0;
                                    2'd1: rbuf_reg[31:16] <= 16'd0;
                                    2'd2: rbuf_reg[31:24] <= 8'd0;
                                    default: rbuf_reg[31:24] <= rbuf_reg[31:24];
                                endcase
                                rbuf_valid_reg    <= 1'b1;
                                rbuf_byte_idx_reg <= 2'd0;
                                flash_cs_n        <= 1'b1;
                            end else if (rbuf_byte_idx_reg == 2'd3) begin
                                rbuf_valid_reg    <= 1'b1;
                                rbuf_byte_idx_reg <= 2'd0;
                            end else begin
                                rbuf_byte_idx_reg <= rbuf_byte_idx_reg + 2'd1;
                            end
                        end
                    end

                    ST_FINISH: begin
                        flash_cs_n <= 1'b1;
                        busy_reg   <= 1'b0;
                        done_reg   <= 1'b1;
                    end

                    ST_ERROR: begin
                        flash_cs_n <= 1'b1;
                        busy_reg   <= 1'b0;
                        err_reg    <= 1'b1;
                    end

                    ST_ABORT: begin
                        flash_cs_n <= 1'b1;
                        busy_reg   <= 1'b0;
                        done_reg   <= 1'b0;
                        err_reg    <= 1'b1;
                    end

                    default: begin
                        flash_cs_n <= 1'b1;
                        busy_reg   <= 1'b0;
                        err_reg    <= 1'b1;
                    end

                endcase
            end
        end
    end

endmodule

`default_nettype wire