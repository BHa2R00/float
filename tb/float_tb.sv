//`define ASYNC
`include "../rtl/float.v"
`timescale 1ns/100ps

module float_tb;

reg clk;
initial clk = 0;
always #1.3020834 clk = ~clk;
reg rstn;

task rstn_p;
	rstn = 0;
	repeat(10) @(negedge clk);
	rstn = 1;
endtask

task rstn_n;
	rstn = 1;
	repeat(10) @(negedge clk);
	rstn = 0;
endtask

reg enable;

parameter MSB	= 31;
parameter FMSB	= 22;

reg [MSB:0] rx_data_1, rx_data_2;
wire [MSB:0] tx_data_1;
reg req_1;
wire ack_1;

localparam EMSB = (((MSB-1)-FMSB)-1);
localparam EMSK = 2**(EMSB+1-1);

fp_add #(
	.MSB(MSB), 
	.FMSB(FMSB)
) u_fp_add(
	.ack(ack_1), 
	.req(req_1), 
	.tx_data(tx_data_1), 
	.rx_data_1(rx_data_1), .rx_data_2(rx_data_2), 
	.enable(enable), 
`ifdef ASYNC
	.async_se(1'b1), .test_se(1'b0), 
`endif
	.rstn(rstn), .clk(clk) 
);

task enable_p;
	enable = 0;
	repeat(10) @(negedge clk);
	enable = 1;
endtask

task enable_n;
	enable = 1;
	repeat(10) @(negedge clk);
	enable = 0;
endtask

task test1;
	$display("test1 start");
	enable_p;
	repeat(100) begin
		req_1 = ~req_1;
		@(posedge ack_1);
		repeat(10) @(negedge clk);
		rx_data_1[MSB] = $urandom_range(0,1);
		rx_data_1[MSB-1:FMSB+1] = $urandom_range(EMSK-32, EMSK+32);
		rx_data_1[FMSB:0] = $urandom_range(0,2**(FMSB+1+2+FMSB+1-1-1));
		rx_data_2[MSB] = $urandom_range(0,1);
		rx_data_2[MSB-1:FMSB+1] = $urandom_range(EMSK-32, EMSK+32);
		rx_data_2[FMSB:0] = $urandom_range(0,2**(FMSB+1+2+FMSB+1-1-1));
		repeat(10) @(negedge clk);
	end
	enable_n;
	$display("test1 end");
endtask

initial begin
	req_1 = 0;
	rx_data_1 = 0;
	rx_data_2 = 0;
	rstn_p;
	repeat(3) test1;
	rstn_n;
	$finish;
end

initial begin
	$fsdbDumpfile("../work/float_tb.fsdb");
	$fsdbDumpvars(0, float_tb);
end

endmodule
