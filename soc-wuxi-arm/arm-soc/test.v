`timescale 1ns/1ns
`define PERIOD 20


module test;

reg clk;
reg resetn;
reg tdi,tck;
wire tms,tdo;
wire [7:0] b_pad_gpio_porta;
wire uart1_rxd,uart2_rxd;
wire timer0_extin,timer1_extin;
wire i2s_sck;
wire i2s_ws;
reg  i2s_sd;
wire flash_cs_n;
wire flash_sclk;
wire flash_mosi;
wire flash_miso;

 top  u_soc(
	.CLK(clk),
	.RESETn(resetn),
	.TDI(tdi),
	.TCK(tck),
	.TMS(tms),
	.TDO(tdo),
	.b_pad_gpio_porta(b_pad_gpio_porta[7:0]),
	.uart1_rxd(uart1_rxd),
	.uart2_rxd(uart2_rxd),
	.uart1_txd(),
	.uart2_txd(),
	.timer0_extin(timer0_extin),
	.timer1_extin(timer1_extin),
	.i2s_sd(i2s_sd),
	.i2s_sck(i2s_sck),
	.i2s_ws(i2s_ws),
	.flash_cs_n(flash_cs_n),
	.flash_sclk(flash_sclk),
	.flash_mosi(flash_mosi),
	.flash_miso(flash_miso));

assign uart1_rxd = 1'b0;
assign uart2_rxd = 1'b0;
assign timer0_extin = 1'b0;
assign timer1_extin = 1'b0;
assign flash_miso = 1'b0;


always #(`PERIOD/2) clk = ~clk;

initial 
   begin
	   clk = 1;
	   resetn = 0;
	   i2s_sd = 1'b0;
	   $readmemh("./cnasic_sleep/prj/keil/output/outfile.bin", u_soc.U_SRAM.memory);
	   $display("*\  ram loaded successfully !");
	   #(`PERIOD*20) resetn =1;
   end
  
  
// initial 
//  begin
//  $fsdbDumpfile("output.fsdb");
//  $fsdbDumpvars;
// end

endmodule