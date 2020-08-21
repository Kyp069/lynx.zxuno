//-------------------------------------------------------------------------------------------------
module keyboard
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      ce,
	input  wire[1:0] ps2,
	output wire      reset,
	output wire      boot
);
//-------------------------------------------------------------------------------------------------

reg      ps2c;
reg      ps2d;
reg      ps2e;
reg[7:0] ps2f;

always @(posedge clock) if(ce)
begin
	ps2d <= ps2[1];
	ps2e <= 1'b0;
	ps2f <= { ps2[0], ps2f[7:1] };

	if(ps2f == 8'hFF) ps2c <= 1'b1;
	else if(ps2f == 8'h00)
	begin
		ps2c <= 1'b0;
		if(ps2c) ps2e <= 1'b1;
	end
end

//-------------------------------------------------------------------------------------------------

reg parity;
reg received;

reg[8:0] data;
reg[3:0] count;
reg[7:0] scancode;

always @(posedge clock) if(ce)
begin
	received <= 1'b0;

	if(ps2e) begin
		if(count == 4'd0) begin
			parity <= 1'b0;
			if(!ps2d) count <= count+4'd1;
		end
		else begin
			if(count < 4'd10) begin
				data <= { ps2d, data[8:1] };
				count <= count+4'd1;
				parity <= parity ^ ps2d;
			end
			else if(ps2d) begin
				count <= 4'd0;
				if(parity) begin
					scancode <= data[7:0];
					received <= 1'b1;
				end
			end
			else count <= 0;
		end
	end
end

//-------------------------------------------------------------------------------------------------

reg pressed = 1'b0;

reg F11; // boot
reg F12; // reset

reg ctrl;
reg alt;
reg del;
reg bs;

initial begin
	F11 = 1'b1;
	F12 = 1'b1;

	ctrl = 1'b1;
	alt = 1'b1;
	del = 1'b1;
	bs = 1'b1;
end

always @(posedge clock) if(ce)
if(received)
	if(scancode == 8'hF0) pressed <= 1'b1; // released
	else
	begin
		pressed <= 1'b0;

		case(scancode)
			8'h78: F11  <= pressed; // F11
			8'h07: F12  <= pressed; // F12

			8'h14: ctrl <= pressed; // ctrl
			8'h11: alt  <= pressed; // alt
			8'h71: del  <= pressed; // del
			8'h66: bs   <= pressed; // bs
		endcase
	end

//-------------------------------------------------------------------------------------------------

assign boot = F11 && (ctrl|alt|bs);
assign reset = F12 && (ctrl|alt|del);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
