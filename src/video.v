//-------------------------------------------------------------------------------------------------
module video
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      ce,
	input  wire      de,
	input  wire      altg,
	input  wire[7:0] di,
	output wire[8:0] rgb,
	output wire[1:0] b
);

//-------------------------------------------------------------------------------------------------

reg[8:0] ves;
wire ve = ves[8];
always @(posedge clock) if(ce) ves <= { ves[7:0], de };

reg[2:0] hCount;
always @(posedge clock) if(ce) if(de|ve) hCount <= hCount+1'd1; else hCount <= 3'b111;

reg[7:0] blueInput;
wire blueInputLoad = (hCount == 1);
always @(posedge clock) if(ce) if(blueInputLoad) blueInput <= di;

reg[7:0] redInput;
wire redInputLoad = (hCount == 3);
always @(posedge clock) if(ce) if(redInputLoad) redInput <= di;

reg[7:0] greenxInput;
wire greenxInputLoad = (hCount == 5);
always @(posedge clock) if(ce) if(greenxInputLoad) greenxInput <= di;

reg[7:0] greenInput;
wire greenInputLoad = (hCount == 7);
always @(posedge clock) if(ce) if(greenInputLoad) greenInput <= di;

reg[7:0] redOutput;
reg[7:0] blueOutput;
reg[7:0] greenOutput;
reg[7:0] greenxOutput;
wire dataOutputLoad = hCount == 0 && ve;

always @(posedge clock) if(ce)
if(dataOutputLoad)
begin
	redOutput <= redInput;
	blueOutput <= blueInput;
	greenOutput <= greenInput;
	greenxOutput <= greenxInput;
end
else
begin
	redOutput <= { redOutput[6:0], 1'b0 };
	blueOutput <= { blueOutput[6:0], 1'b0 };
	greenOutput <= { greenOutput[6:0], 1'b0 };
	greenxOutput <= { greenxOutput[6:0], 1'b0 };
end

assign rgb = ve ? { {3{redOutput[7]}}, {3{altg ? greenxOutput[7] : greenOutput[7]}}, {3{blueOutput[7]}} } : 9'd0;

assign b = hCount[2:1];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
