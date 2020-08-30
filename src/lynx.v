//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K implementation for ZX-Uno board by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
// Z80 chip module implementation by Sorgelig
// https://github.com/sorgelig/ZX_Spectrum-128K_MIST
//-------------------------------------------------------------------------------------------------
// Define either Lynx48K or Lynx96K to select model in
// Synthesize - XST, Process properties, Advanced parameter "-define" (Verilog Macros)
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
	.int    (int    ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.di     (di     ),
	.do     (do     ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

`ifdef Lynx48K

wire[ 7:0] romDo;
wire[13:0] romA;

rom #(.AW(14), .FN("48K-1+2.hex")) Rom
(
	.clock  (clock  ),
	.ce     (ce4p   ),
	.do     (romDo  ),
	.a      (romA   )
);

`elsif Lynx96K

wire[ 7:0] romDo;
wire[14:0] romA;

rom #(.AW(15), .FN("96K-1+2+3s.hex")) Rom
(
	.clock  (clock  ),
	.ce     (ce4p   ),
	.do     (romDo  ),
	.a      (romA   )
);

`endif

//-------------------------------------------------------------------------------------------------

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

wire[ 7:0] vggDo1;
wire[13:0] vggA1;
wire[ 7:0] vggDi2;
wire[ 7:0] vggDo2;
wire[13:0] vggA2;

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

wire io7F = !(!iorq && !wr && a[6:0] == 7'h7F);

reg[7:0] reg7F;
always @(negedge reset, posedge clock) if(!reset) reg7F <= 1'd0; else if(ce4p) if(!io7F) reg7F <= do;

//-------------------------------------------------------------------------------------------------

wire io80 = !(!iorq && !wr && a[7] && !a[6] && !a[2] && !a[1]);

reg[5:1] reg80;
always @(negedge reset, posedge  clock) if(!reset) reg80 <= 1'd0; else if(ce4p) if(!io80) reg80 <= do[5:1];

//-------------------------------------------------------------------------------------------------

wire io84 = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && !a[1]);

reg[5:0] reg84;
always @(posedge clock) if(ce4p) if(!io84) reg84 <= do[5:0];

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
	.int    (int    ),
	.d      (vmmDi  ),
	.b      (vmmB   ),
	.a      (vmmA   )
);

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
	.ce     (ce8p   ),
	.ps2    (ps2    ),
	.reset  (reset  ),
	.boot   (boot   ),
	.row    (keybRow),
	.do     (keybDo )
);

//-------------------------------------------------------------------------------------------------

`ifdef Lynx48K

assign romA = a[13:0];

`elsif Lynx96K

assign romA = a[14:0];

`endif

//-------------------------------------------------------------------------------------------------

assign ramWe = !(!mreq && !wr && !reg7F[0]);
assign ramD = ramWe ? 8'hZZ : do;

`ifdef Lynx48K

assign ramA = { 7'b0000000,  a[14], a[12:0] };

`elsif Lynx96K

assign ramA = { 5'b00000, a };

`endif

//-------------------------------------------------------------------------------------------------

assign vrbA1 = { vmmB[0], vmmA };
assign vrbWe2 = !(!mreq && !wr && reg7F[1] && reg80[5]);
assign vrbDi2 = do;
assign vrbA2 = { a[14], a[12:0] };

assign vggA1 = { vmmB[0], vmmA };
assign vggWe2 = !(!mreq && !wr && reg7F[2] && reg80[5]);
assign vggDi2 = do;
assign vggA2 = { a[14], a[12:0] };

assign vmmDi = vmmB[1] ? vggDo1 : vrbDo1;

//-------------------------------------------------------------------------------------------------

assign di
	= !mreq && !reg7F[4] && a[15:14] == 2'b00  ? romDo
	: !mreq && !reg7F[4] && a[15:13] == 3'b010 ? 8'hFF
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
