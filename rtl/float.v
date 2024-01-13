module fp_add #(
	parameter MSB	= 31, 
	parameter FMSB	= 22
)(
	output ack, 
	output reg [3:0] cst, nst, 
	input req, 
	output reg [MSB:0] tx_data, 
	input [MSB:0] rx_data_1, rx_data_2, 
	input enable, 
`ifdef ASYNC
	input async_se, lck, test_se, 
`endif
	input rstn, clk 
);

`ifdef ASYNC
wire clk0 = test_se ? clk : async_se ? lck  : clk;
`endif

wire [FMSB+1+2+FMSB+1-1:0] frac_rx_data_1 = {{(FMSB+1){1'b0}}, 2'b01, rx_data_1[FMSB:0]};
wire [FMSB+1+2+FMSB+1-1:0] frac_rx_data_2 = {{(FMSB+1){1'b0}}, 2'b01, rx_data_2[FMSB:0]};
localparam EMSB = (((MSB-1)-FMSB)-1);
localparam EMSK = 2**(EMSB+1-1);
reg [EMSB:0] expt, expt_b;
reg [FMSB+1+2+FMSB+1-1:0] frac, frac_b;
wire [EMSB:0] diff_expt = expt - expt_b;
wire [EMSB:0] abs_diff_expt = diff_expt[EMSB] ? ~diff_expt + 1 : diff_expt;
wire sign = frac[FMSB+1+2+FMSB+1-1];
wire sign_b = frac_b[FMSB+1+2+FMSB+1-1];
wire [FMSB+1+2+FMSB+1-1:0] abs_frac = sign ? ~frac + 1 : frac;
wire [FMSB+1+2+FMSB+1-1:0] abs_frac_b = sign_b ? ~frac_b + 1 : frac_b;
wire eq0_1 = (expt == 0) && (abs_frac[FMSB:0] == 0);
wire eq0_2 = (expt_b == 0) && (abs_frac_b[FMSB:0] == 0);
wire shift_p = diff_expt[EMSB];
wire shift_b_p = (diff_expt != 0) && ~shift_p;
wire shift_right_p = (abs_frac[FMSB+1+2+FMSB+1-1:FMSB+1] > 1) && ~(abs_frac == 0);
wire shift_left_p = (abs_frac[FMSB+1+2+FMSB+1-1:FMSB+1] == 0) && ~(abs_frac == 0);

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [3:0]
	st_tx_data		= `GRAY(12),
	st_shift_left	= `GRAY(11),
	st_shift_right	= `GRAY(10),
	st_adjust		= `GRAY(9),
	st_add			= `GRAY(8),
	st_shift_b		= `GRAY(7),
	st_shift		= `GRAY(6),
	st_check_expt	= `GRAY(5),
	st_rx_data_2	= `GRAY(4),
	st_check_eq0	= `GRAY(3),
	st_load			= `GRAY(2),
	st_idle			= `GRAY(1);
reg req_d;
`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) req_d <= 1'b0;
	else if(enable) req_d <= req;
end
wire req_x = req_d ^ req;
`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) cst <= st_idle;
	else if(enable) cst <= nst;
	else cst <= st_idle;
end
always@(*) begin
	case(cst)
		st_idle: nst = req_x ? st_load : cst;
		st_load: nst = st_check_eq0;
		st_check_eq0: nst = eq0_1 ? st_rx_data_2 : eq0_2 ? st_tx_data : st_check_expt;
		st_rx_data_2: nst = st_tx_data;
		st_check_expt: nst = shift_p ? st_shift : shift_b_p ? st_shift_b : st_add;
		st_shift: nst = st_check_expt;
		st_shift_b: nst = st_check_expt;
		st_add: nst = st_adjust;
		st_adjust: nst = shift_right_p ? st_shift_right : shift_left_p ? st_shift_left : st_tx_data;
		st_shift_right: nst = st_adjust;
		st_shift_left: nst = st_adjust;
		st_tx_data: nst = st_idle;
		default: nst = st_idle;
	endcase
end
assign ack = cst == st_idle;

`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) begin
		expt <= 0; frac <= 0;
		expt_b <= 0; frac_b <= 0;
	end
	else if(enable) begin
		case(nst)
			st_load: begin
				expt <= rx_data_1[MSB-1:FMSB+1] - EMSK; 
				expt_b <= rx_data_2[MSB-1:FMSB+1] - EMSK;
				frac <= rx_data_1[MSB] ? (~frac_rx_data_1 + 1) : frac_rx_data_1;
				frac_b <= rx_data_2[MSB] ? (~frac_rx_data_2 + 1) : frac_rx_data_2;
			end
			st_rx_data_2: begin
				expt <= expt_b;
				frac <= frac_b;
			end
			st_shift: begin
				expt <= expt + 1;
				frac <= sign ?  (~(abs_frac >> 1) + 1) : (abs_frac >> 1);
			end
			st_shift_b: begin
				expt <= expt - 1;
				frac <= sign ?  (~(abs_frac << 1) + 1) : (abs_frac << 1);
			end
			st_add: frac <= frac + frac_b;
			st_shift_right: begin
				expt <= expt + 1;
				frac <= sign ? (~(abs_frac >> 1) + 1) : (abs_frac >> 1);
			end
			st_shift_left: begin
				expt <= expt - 1;
				frac <= sign ? (~(abs_frac << 1) + 1) : (abs_frac << 1);
			end
			default: begin
				expt <= expt; frac <= frac;
				expt_b <= expt_b; frac_b <= frac_b;
			end
		endcase
	end
	else begin
		expt <= 0; frac <= 0;
		expt_b <= 0; frac_b <= 0;
	end
end

`ifdef ASYNC
always@(negedge rstn or posedge clk0) begin
`else
always@(negedge rstn or posedge clk) begin
`endif
	if(!rstn) tx_data <= 0;
	else if(enable) begin
		case(nst)
			st_tx_data: begin
				tx_data[MSB] <= sign;
				tx_data[MSB-1:FMSB+1] <= expt + EMSK;
				tx_data[FMSB:0] <= abs_frac[FMSB:0];
			end
			default: tx_data <= tx_data;
		endcase
	end
	else tx_data <= 0;
end

endmodule
