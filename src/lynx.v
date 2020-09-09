//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation for ZX-Uno board by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
// Z80 chip module implementation by Sorgelig
// https://github.com/sorgelig/ZX_Spectrum-128K_MIST
//-------------------------------------------------------------------------------------------------
// UM6845 CRTC chip module implementation by Sorgelig
// https://github.com/sorgelig/Amstrad_MiST
// Some minor modifications done
//-------------------------------------------------------------------------------------------------
module lynx
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,
	output wire       led,

	output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 8:0] rgb,

	input  wire       ear,
	output wire[ 1:0] audio,

	input  wire[ 1:0] ps2,
	input  wire[ 5:0] joy,

	output wire       ramWe,
	inout  wire[ 7:0] ramD,
	output wire[20:0] ramA
);
//-------------------------------------------------------------------------------------------------

localparam ramAW = 16; // 14 = Lynx 48K, 16 = Lynx 96K/96Kscorpion
localparam romAW = 15; // 14 = Lynx 48K, 15 = Lynx 96K/96Kscorpion
localparam romFN = "96K-1+2+3s.hex"; // "48K-1+2.hex" : "96K-1+2+3.hex" : "96K-1+2+3s.hex"

//-------------------------------------------------------------------------------------------------

clock Clock
(
	.i      (clock50),
	.o      (clock  )  // 48 MHz
);

reg[5:0] ce = 0;
always @(negedge clock) ce <= ce+1'd1;

wire ce600p = ~ce[0] & ~ce[1] &  ce[2];
wire ce075p = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3] & ~ce[4] &  ce[5];

reg[3:0] ce4 = 0;
always @(negedge clock) if(ce400p) ce4 <= 1'd0; else ce4 <= ce4+1'd1;

wire ce400p = ce4[0] &  ce4[1]          &  ce4[3];
wire ce400n = ce4[0] & ~ce4[1] & ce4[2] & ~ce4[3];

//-------------------------------------------------------------------------------------------------

BUFG  Bufg (.I(ce[0]), .O(clockmb));

multiboot Multiboot
(
    .clock  (clockmb),
    .reset  (boot   )
);

//-------------------------------------------------------------------------------------------------

wire int = ~cursor;

wire[ 7:0] di;
wire[ 7:0] do;
wire[15:0] a;

cpu Cpu
(
	.reset  (reset  ),
	.clock  (clock  ),
	.cep    (ce400p ),
	.cen    (ce400n ),
	.int    (int    ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.di     (di     ),
	.do     (do     ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] romDo;
wire[romAW-1:0] romA;

rom #(.AW(romAW), .FN(romFN)) Rom
(
	.clock  (clock  ),
	.ce     (ce400p ),
	.do     (romDo  ),
	.a      (romA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] vrbDo1;
wire[13:0] vrbA1;
wire[ 7:0] vrbDi2;
wire[ 7:0] vrbDo2;
wire[13:0] vrbA2;

dpr #(.AW(14)) Vrb
(
	.clock  (clock  ),
	.ce1    (ce600p ),
	.do1    (vrbDo1 ),
	.a1     (vrbA1  ),
	.ce2    (ce400p ),
	.we2    (vrbWe2 ),
	.di2    (vrbDi2 ),
	.do2    (vrbDo2 ),
	.a2     (vrbA2  )
);

wire[ 7:0] vggDo1;
wire[13:0] vggA1;
wire[ 7:0] vggDi2;
wire[ 7:0] vggDo2;
wire[13:0] vggA2;

dpr #(.AW(14)) Vgg
(
	.clock  (clock  ),
	.ce1    (ce600p ),
	.do1    (vggDo1 ),
	.a1     (vggA1  ),
	.ce2    (ce400p ),
	.we2    (vggWe2 ),
	.di2    (vggDi2 ),
	.do2    (vggDo2 ),
	.a2     (vggA2  )
);

//-------------------------------------------------------------------------------------------------

wire io7F = !(!iorq && !wr && a[6:0] == 7'h7F);

reg[7:0] reg7F;
always @(negedge reset, posedge clock) if(!reset) reg7F <= 1'd0; else if(ce400p) if(!io7F) reg7F <= do;

//-------------------------------------------------------------------------------------------------

wire io80 = !(!iorq && !wr && a[7] && !a[6] && !a[2] && !a[1]);

reg[5:1] reg80;
always @(negedge reset, posedge  clock) if(!reset) reg80 <= 1'd0; else if(ce400p) if(!io80) reg80 <= do[5:1];

//-------------------------------------------------------------------------------------------------

wire io84 = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && !a[1]);

reg[5:0] reg84;
always @(posedge clock) if(ce400p) if(!io84) reg84 <= do[5:0];

//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && a[1]);
wire crtcRs = a[0];
wire crtcRw = wr;

wire[ 7:0] crtcDi = do;

wire[13:0] crtcMa;
wire[ 4:0] crtcRa;

UM6845R Crtc
(
	.TYPE   (1'b0   ),
	.CLOCK  (clock  ),
	.CLKEN  (ce075p ),
	.nRESET (reset  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (crtcDi ),
	.DO     (       ),
	.VSYNC  (vSync  ),
	.HSYNC  (hSync  ),
	.DE     (crtcDe ),
	.FIELD  (       ),
	.CURSOR (cursor ),
	.MA     (crtcMa ),
	.RA     (crtcRa )
);

//-------------------------------------------------------------------------------------------------

wire altg = reg80[4];

wire[7:0] vduDi;
wire[1:0] vduB;

video Video
(
	.reset  (~hSync ),
	.clock  (clock  ),
	.ce     (ce600p ),
	.de     (crtcDe ),
	.altg   (altg   ),
	.di     (vduDi  ),
	.rgb    (rgb    ),
	.b      (vduB   )
);

assign stdn = 2'b01; // PAL
assign sync = { 1'b1, ~(hSync^vSync) };

//-------------------------------------------------------------------------------------------------

audio Audio
(
	.clock  (clock  ),
	.reset  (reset  ),
	.ear    (!ear   ),
	.dac    (reg84  ),
	.audio  (audio  )
);

//-------------------------------------------------------------------------------------------------

wire[3:0] keybRow = a[11:8];
wire[7:0] keybDo;

keyboard Keyboard
(
	.clock  (clock  ),
	.ce     (ce600p ),
	.ps2    (ps2    ),
	.reset  (reset  ),
	.boot   (boot   ),
	.cas    (cas    ),
	.row    (keybRow),
	.do     (keybDo )
);

//-------------------------------------------------------------------------------------------------

assign romA = a[romAW-1:0];

assign ramWe = !(!mreq && !wr && !reg7F[0]);
assign ramD = ramWe ? 8'hZZ : do;
assign ramA = { 5'b00000, ramAW == 14 ? { 2'b00,  a[14], a[12:0] } : a };

//-------------------------------------------------------------------------------------------------

reg casd;
reg cas23;

always @(posedge clock) if(ce600p)
begin
	casd <= cas;
	if(casd && !cas) cas23 <= ~cas23;
end

assign vduDi = vduB[1] ? (!cas23 || !reg80[3] ? vggDo1 : 8'h00) : (!cas23 || !reg80[2] ? vrbDo1 : 8'h00);
wire[12:0] vmmA = { crtcMa[10:5], crtcRa[1:0], crtcMa[4:0] };

//-------------------------------------------------------------------------------------------------

assign vrbA1 = { vduB[0], vmmA };
assign vrbWe2 = !(!mreq && !wr && reg7F[1] && reg80[5]);
assign vrbDi2 = do;
assign vrbA2 = { a[14], a[12:0] };

assign vggA1 = { vduB[0], vmmA };
assign vggWe2 = !(!mreq && !wr && reg7F[2] && reg80[5]);
assign vggDi2 = do;
assign vggA2 = { a[14], a[12:0] };

//-------------------------------------------------------------------------------------------------

assign di

	= !mreq && !reg7F[4] && a[15:14] == 2'b00 ? romDo
	: !mreq && !reg7F[4] && a[15:13] == 3'b010 ? (romAW == 14 ? 8'hFF : romDo)
	: !mreq && !reg7F[5] ? ramD
	: !mreq &&  reg7F[6] && !reg80[2] ? vrbDo2
	: !mreq &&  reg7F[6] && !reg80[3] ? vggDo2
	: !iorq &&  a[7:0] == 8'h80 ? { keybDo[7:1], reg80[1] ? ear : keybDo[0] }
	: !iorq &&  a[6:0] == 8'h7A ? { 2'b00, joy }
	: 8'hFF;

assign led = ~ear;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
