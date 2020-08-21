//-------------------------------------------------------------------------------------------------
// Linkx48: Lynx 48K implementation for ZX-Uno board by Kyp
// https://github.com/Kyp069/lynx48
//-------------------------------------------------------------------------------------------------
// Z80 chip module implementation by Sorgelig
// https://github.com/sorgelig/ZX_Spectrum-128K_MIST
//-------------------------------------------------------------------------------------------------
module lynx48
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock50,
//	output wire      led,

	output wire[1:0] stdn,
	output wire[1:0] sync,
	output wire[8:0] rgb,

//	input  wire      ear,
	output wire[1:0] audio,

	input  wire[1:0] ps2
);
//-------------------------------------------------------------------------------------------------

clock Clock
(
	.i      (clock50),
	.o      (clock  )
);

reg[2:0] ce;
always @(negedge clock) ce <= ce+1'd1;

wire ce8n = ~ce[0] & ~ce[1];
wire ce8p = ~ce[0] &  ce[1];

wire ce4n = ~ce[0] & ~ce[1] & ~ce[2];
wire ce4p = ~ce[0] & ~ce[1] &  ce[2];

//-------------------------------------------------------------------------------------------------

BUFG  Bufg (.I(ce[0]), .O(clockmb));

multiboot Multiboot
(
    .clock  (clockmb),
    .reset  (boot   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] di;
wire[ 7:0] do;
wire[15:0] a;

cpu Cpu
(
	.reset  (reset  ),
	.clock  (clock  ),
	.cep    (ce4p   ),
	.cen    (ce4n   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.di     (di     ),
	.do     (do     ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] romDo;
wire[13:0] romA;

rom #(.AW(14), .FN("48K-1+2.hex")) Rom
(
	.clock  (clock  ),
	.ce     (ce4p   ),
	.do     (romDo  ),
	.a      (romA   )
);

wire[ 7:0] ramDi;
wire[ 7:0] ramDo;
wire[13:0] ramA;

spr #(.AW(14)) Ram
(
	.clock  (clock  ),
	.ce     (ce4p   ),
	.we     (ramWe  ),
	.di     (ramDi  ),
	.do     (ramDo  ),
	.a      (ramA   )
);

wire[ 7:0] vrbDo1;
wire[13:0] vrbA1;
wire[ 7:0] vrbDi2;
wire[ 7:0] vrbDo2;
wire[13:0] vrbA2;

dpr #(.AW(14)) Vrb
(
	.clock  (clock  ),
	.ce1    (ce8n   ),
	.do1    (vrbDo1 ),
	.a1     (vrbA1  ),
	.ce2    (ce4p   ),
	.we2    (vrbWe2 ),
	.di2    (vrbDi2 ),
	.do2    (vrbDo2 ),
	.a2     (vrbA2  )
);

wire[ 7:0] mggDo1;
wire[13:0] mggA1;
wire[ 7:0] mggDi2;
wire[ 7:0] mggDo2;
wire[13:0] mggA2;

dpr #(.AW(14)) Vgg
(
	.clock  (clock  ),
	.ce1    (ce8n   ),
	.do1    (vggDo1 ),
	.a1     (vggA1  ),
	.ce2    (ce4p   ),
	.we2    (vggWe2 ),
	.di2    (vggDi2 ),
	.do2    (vggDo2 ),
	.a2     (vggA2  )
);

//-------------------------------------------------------------------------------------------------

wire ioFF = !(!iorq && a[13] && a[6:0] == 7'h3F);

reg[7:0] regFF;
always @(negedge reset, posedge clock) if(!reset) regFF <= 1'd0; else if(ce4p) if(!ioFF && !wr) regFF <= do;

//-------------------------------------------------------------------------------------------------

wire io80 = !(!iorq && a[7] && !a[6] && !a[2] & !a[1]);

reg[6:2] reg80;
always @(negedge reset, posedge clock) if(!reset) reg80 <= 1'd0; else if(ce4p) if(!io80 && !wr) reg80 <= do[6:2];

//-------------------------------------------------------------------------------------------------

wire io84 = !(!iorq && a[7] && !a[6] &&  a[2] & !a[1]);

reg[5:0] reg84;
always @(negedge reset, posedge clock) if(!reset) reg84 <= 1'd0; else if(ce4p) if(!io84 && !wr) reg84 <= do[5:0];

//-------------------------------------------------------------------------------------------------

wire altg = reg80[4];

wire[ 7:0] vmmDi;
wire[ 1:0] vmmB;
wire[12:0] vmmA;

video Video
(
	.clock  (clock  ),
	.ce     (ce8n   ),
	.altg   (altg   ),
	.stdn   (stdn   ),
	.sync   (sync   ),
	.rgb    (rgb    ),
	.d      (vmmDi  ),
	.b      (vmmB   ),
	.a      (vmmA   )
);

//-------------------------------------------------------------------------------------------------

dac #(.MSBI(5)) Dac
(
	.reset  (reset  ),
	.clock  (clock  ),
	.di     (reg84  ),
	.do     (dacDo  )
);

assign audio = {2{dacDo}};

//-------------------------------------------------------------------------------------------------

keyboard Keyboard
(
	.clock  (clock  ),
	.ce     (ce8p   ),
	.ps2    (ps2    ),
	.reset  (reset  ),
	.boot   (boot   )
);

//-------------------------------------------------------------------------------------------------

assign romA = { a[14], a[12:0] };

assign ramWe = !(!mreq && !wr && !regFF[0]);
assign ramDi = do;
assign ramA = { a[14], a[12:0] };

assign vrbA1 = { vmmB[0], vmmA };
assign vrbWe2 = !(!mreq && !wr && regFF[1] && reg80[5]);
assign vrbDi2 = do;
assign vrbA2 = { a[14], a[12:0] };

assign vggA1 = { vmmB[0], vmmA };
assign vggWe2 = !(!mreq && !wr && regFF[2] && reg80[5]);
assign vggDi2 = do;
assign vggA2 = { a[14], a[12:0] };

assign vmmDi = vmmB[1] ? vggDo1 : vrbDo1;

//-------------------------------------------------------------------------------------------------

assign di
	= !mreq && rd && !regFF[4] && !a[15] && (!a[14] || !a[13]) ? romDo
	: !mreq && rd && !regFF[5] ? ramDo
	: !mreq && rd &&  regFF[6] && !reg80[2] ? vrbDo2
	: !mreq && rd &&  regFF[6] && !reg80[3] ? vggDo2
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------