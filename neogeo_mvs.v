`timescale 10ns/10ns

// SNK NeoGeo FPGA hardware definitions (for simulation only)
// furrtek, Charles MacDonald, Kyuusaku and neogeodev contributors ~ 2016
// https://github.com/neogeodev/NeoGeoFPGA-sim

module neogeo_mvs(
	input RESET_BTN,
	input TEST_BTN,				// Todo
	input [7:0] DIPSW,
	input [9:0] P1_IN,
	input [9:0] P2_IN,
	output [2:0] P1_OUT,
	output [2:0] P2_OUT,
	output [23:0] CDA,			// Memcard address
	output [3:0] EL_OUT,			// Clock, 3x data
	output [8:0] LED_OUT1,		// Clock, 8x data
	output [8:0] LED_OUT2,		// Clock, 8x data
	output reg [6:0] VIDEO_R,
	output reg [6:0] VIDEO_G,
	output reg [6:0] VIDEO_B,
	output VIDEO_SYNC
);

	// Todo: Check watchdog timing
	// Todo: VPA (NEO-C1)
	// TODO: ERROR ! BITWD0 should ignore M68K_ADDR[5] (see writes to NEO-F0)

	// REG_P1CNT		Read ok, check range
	//	REG_DIPSW		Read ok, Write ok, check range
	// REG_TYPE			Read mapped, check range
	// REG_SOUND		Read ok, write todo, check range
	// REG_STATUS_A	Read mapped, check range
	// REG_P2CNT		Read ok, check range
	// REG_STATUS_B	Read ok, check range
	// REG_POUTPUT		Write ok, check range
	// REG_CRDBANK		Write ok, check range
	// REG_SLOT			Write ok, check range
	// REG_LEDLATCHES	Write ok, check range
	// REG_LEDDATA		Write ok, check range
	// REG_RTCCTRL		Write ok, check range
	
	// Counter/lockout	Ok, check range, neo_i0.v
	
	wire A22Z;
	wire A23Z;
	wire [22:0] M68K_ADDR;	// Really A23~A1
	wire [15:0] M68K_DATA;
	wire M68K_RW;
	wire nDTACK;
	
	wire [7:0] SDD;			// Z80 data bus
	
	wire nPAL, nPALWE;
	wire nSROMOEU, nSROMOEL;
	
	wire [15:0] G;				// SFIX address
	wire [7:0] FIXD;
	wire [7:0] FIXD_CART;
	wire [7:0] FIXD_EMBED;
	wire [11:0] PA;			// Palette RAM address
	wire [3:0] GAD, GBD;		// Pixel pair
	wire [23:0] PBUS;
	wire [31:0] CR;			// Raw sprite data
	wire [15:0] PC;			// Palette RAM data
	wire [3:0] WE;				// LSPC/B1
	wire [3:0] CK;				// LSPC/B1
	
	wire S2H1;
	wire SYSTEMB;
	wire nSYSTEM;
	
	wire CLK_24M;
	wire nRESETP;
	wire nVEC, SHADOW;
	wire nBNKB;
	
	
	// NEO-C1:nBITW0(38xxxx-39xxxx) -> NEO-F0:nBITWD0(A7~6=0) -> NEO-D0
	assign nBITWD0 = nBITW0 & (M68K_ADDR[6] | M68K_ADDR[5]);
	
	//                     7654 3210
	// NEO-D0 (nBITWD0)
	// 0000 0000 0000 0000 000x 0000
	
	// NEO-F0
	// 0000 0000 0000 0000 0101 xxxx
	// 0000 0000 0000 0000 0100 xxxx
	// 0000 0000 0000 0000 0011 xxxx
	// 0000 0000 0000 0000 0010 xxxx
	// 0000 0000 0000 0000 0001 xxxx
	// 0000 0000 0000 0000 1101 xxxx ?
	
	wire [5:0] SLOT;
	
	// Implementation specific (unique slot)
	assign nSLOTCS = SLOT[0];
	
	// For NEO-I0:
	assign nCOUNTOUT = &{nBITW0, ~M68K_ADDR[5], M68K_ADDR[4:3]};	// nBITW0 or nBITWD0 ?
	// NEO-F0: A6~4 (5~3)
	// xx10 0xxx
	
	clocks CLK(CLK_24M, nRESETP, CLK_12M, CLK_68KCLK, CLK_68KCLKB, CLK_8M, CLK_6MB, CLK_4M, CLK_4MB, CLK_1MB);

	mvs_cart CART(PBUS, CA4, S2H1, PCK1B, PCK2B, CR, FIXD_CART, M68K_ADDR[18:0], M68K_DATA, nROMOE,
					nPORTOEL, nPORTOEU, nSLOTCS);

	neo_zmc2 ZMC2(CLK_12M, EVEN, LOAD, H, CR, GAD, GBD, DOTA, DOTB);
	
	neo_c1 C1(M68K_ADDR[20:16], M68K_DATA[15:8], A22Z, A23Z, nLDS, nUDS, M68K_RW, AS, nROMOEL, nROMOEU, nPORTOEL, nPORTOEU,
				nPORTWEL, nPORTWEU, nPORTADRS, nWRL, nWRU, nWWL, nWWU, nSROMOEL, nSROMOEU, nSRAMOEL, nSRAMOEU, nSRAMWEL,
				nSRAMWEU, nLSPOE, nLSPWE, nCRDO, nCRDW, nCRDC, nSDW, P1_IN, P2_IN, nCD1, nCD2, nWP, ROMWAIT, PWAIT0,
				PWAIT1, PDTACK, SDD, CLK_68KCLK, nDTACK, nBITW0, nBITW1, nDIPRD0, nDIPRD1, nPAL);
				
	neo_d0 D0(M68K_ADDR[21:0], nBITWD0, M68K_DATA[5:0], CDA, P1_OUT, P2_OUT);
	
	neo_f0 F0(nDIPRD0, nDIPRD1, nBITWD0, DIPSW, M68K_ADDR[6:3], M68K_DATA[7:0], SYSTEMB, SLOT, SLOTA, SLOTB, SLOTC,
				EL_OUT, LED_OUT1, LED_OUT2);	

	lspc_a2 LSPC(CLK_24M, nRESET, PBUS, M68K_ADDR[2:0], M68K_DATA, nLSPOE, nLSPWE, DOTA, DOTB, CA4, S2H1,
				S1H1, LOAD, H, EVEN1, EVEN2, IPL0, IPL1, CHG, LD1, LD1, PCK1, PCK2, WE[3:0], CK[3:0], SS1,
				SS2, nRESETP, VIDEO_SYNC, CHBL, nBNKB, nVCS, CLK_6M);
				
	neo_b1 B1(PBUS, FIXD, PCK1, PCK2, GAD, GBD, WE, CK, TMS0, LD1, LD2, SS1, SS2, A23Z, A22Z, PA, nLDS, M68K_RW,
				M68K_ADDR[20:16], M68K_ADDR[11:0], nHALT, nRESET, VCCON);
	
	neo_i0 I0(nRESET, nCOUNTOUT, M68K_ADDR[2:0], M68K_ADDR[7], COUNTER1, COUNTER2, LOCKOUT1, LOCKOUT2);
	
	syslatch SL(M68K_ADDR[3:0], nBITW1, nRESET,
				SHADOW, nVEC, nCARDWEN, CARDWENB, nREGEN, nSYSTEM, nSRAMLOCK, nPALBANK);
	
	rom_l0 L0(PBUS[15:0], PBUS[23:16], nVCS);
	rom_sps2 SP(M68K_ADDR[15:0], M68K_DATA[15:0], nSROMOE);
	rom_sfix SFIX({G[15:3], S2H1, G[2:0]}, FIXD_EMBED, nSYSTEM);

	palram PRAML({PALBNK, PA}, PC[7:0], nPALWE, 1'b0, 1'b0);
	palram PRAMU({PALBNK, PA}, PC[15:8], nPALWE, 1'b0, 1'b0);
	
	// Gates
	assign PCK1B = ~PCK1;
	assign PCK2B = ~PCK2;
	assign nSROMOE = nSROMOEU & nSROMOEL;
	assign nPALWE = M68K_RW & nPAL;
	assign SYSTEMB = ~nSYSTEM;	// ?
	
	// Good job SNK ! Gates cart FIXD to avoid bus wreck with SFIX
	assign FIXD = nSYSTEM ? FIXD_EMBED : FIXD_CART;
	
	// This is done by NEO-E0:
	// A' = 1 if nVEC == 0 and A == 11000000000000000xxxxxxx
	assign {A23Z, A22Z} = M68K_ADDR[22:21] ^ {2{~|{M68K_ADDR[20:6], ^M68K_ADDR[22:21], nVEC}}};
	
	// Palette data bidir buffer from/to 68k
	assign M68K_DATA = (M68K_RW | ~nPAL) ? PC : 16'bzzzzzzzzzzzzzzzz;
	assign PC = nPALWE ? M68K_DATA : 16'bzzzzzzzzzzzzzzzz;
	
	// Color data latch/blanking
	always @(posedge CLK_6MB)
	begin
		VIDEO_R <= nBNKB ? {SHADOW, PC[11:8], PC[14], PC[15]} : 7'b0000000;
		VIDEO_G <= nBNKB ? {SHADOW, PC[7:4], PC[13], PC[15]} : 7'b0000000;
		VIDEO_B <= nBNKB ? {SHADOW, PC[3:0], PC[12], PC[15]} : 7'b0000000;
	end

endmodule
