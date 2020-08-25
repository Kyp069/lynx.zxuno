//-------------------------------------------------------------------------------------------------
module video
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       ce,
	input  wire       altg,
	output wire       int,
	output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 8:0] rgb,
	input  wire[ 7:0] d,
	output wire[ 1:0] b,
	output wire[12:0] a
);
//-------------------------------------------------------------------------------------------------

reg[8:0] hCount;
wire hCountReset = hCount >= 447;
always @(posedge clock) if(ce) if(hCountReset) hCount <= 9'd0; else hCount <= hCount+9'd1;

reg[8:0] vCount;
wire vCountReset = vCount >= 311;
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) vCount <= 9'd0; else vCount <= vCount+9'd1;

//-------------------------------------------------------------------------------------------------

wire dataEnable = hCount <= 255 && vCount <= 247;

reg videoEnable;
wire videoEnableLoad = hCount[2];
always @(posedge clock) if(ce) if(videoEnableLoad) videoEnable <= dataEnable;

//-------------------------------------------------------------------------------------------------

reg[7:0] redInput;
reg[7:0] blueInput;
reg[7:0] greenInput;
//reg[7:0] greenxInput;

wire blueInputLoad = (hCount[2:0] == 1) && dataEnable;
always @(posedge clock) if(ce) if(blueInputLoad) blueInput <= d;

wire redInputLoad = (hCount[2:0] == 3) && dataEnable;
always @(posedge clock) if(ce) if(redInputLoad) redInput <= d;

reg[7:0] greenxInput;
wire greenxInputLoad = (hCount[2:0] == 5) && dataEnable;
always @(posedge clock) if(ce) if(greenxInputLoad) greenxInput <= d;

//reg[7:0] greenInput;
//wire greenInputLoad = (hCount[2:0] == 7) && dataEnable;
//always @(posedge clock) if(ce) if(greenInputLoad) greenInput <= d;

//-------------------------------------------------------------------------------------------------

reg[7:0] redOutput;
reg[7:0] blueOutput;
reg[7:0] greenOutput;
reg[7:0] greenxOutput;
wire dataOutputLoad = hCount[2:0] == 7 && videoEnable;

always @(posedge clock)
if(ce)
if(dataOutputLoad)
begin
	redOutput <= redInput;
	blueOutput <= blueInput;
	greenOutput <= d;
	greenxOutput <= greenxInput;
end
else
begin
	redOutput <= { redOutput[6:0], 1'b0 };
	blueOutput <= { blueOutput[6:0], 1'b0 };
	greenOutput <= { greenOutput[6:0], 1'b0 };
	greenxOutput <= { greenxOutput[6:0], 1'b0 };
end

//-------------------------------------------------------------------------------------------------

wire videoBlank = (hCount >= 320 && hCount <= 415) || (vCount >= 248 && vCount <= 255);

wire hSync = hCount >= 344 && hCount <= 375;
wire vSync = vCount >= 260 && vCount <= 263;

//-------------------------------------------------------------------------------------------------

assign int = !(vCount == 248 && hCount >= 2 && hCount <= 65);

assign stdn = 2'b01; // PAL
assign sync = { 1'b1, ~(hSync|vSync) };
assign rgb = videoBlank || !videoEnable ? 9'd0 : { {3{redOutput[7]}}, {3{blueOutput[7]}}, {3{altg ? greenxOutput[7] : greenOutput[7]}} };

assign b = hCount[2:1];
assign a = { vCount[7:0], hCount[7:3] };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
