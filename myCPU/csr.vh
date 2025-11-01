`define CSR_CRMD 13'h0
`define CSR_PRMD 13'h1
`define CSR_EUEN 13'h02
`define CSR_ECFG 13'h4
`define CSR_ESTAT 13'h5
`define CSR_ERA 13'h6
`define CSR_BADV 13'h7
`define CSR_EENTRY 13'hc
`define CSR_SAVE0 13'h30
`define CSR_SAVE1 13'h31
`define CSR_SAVE2 13'h32
`define CSR_SAVE3 13'h33
`define CSR_TID 13'h40 
`define CSR_TCFG 13'h41
`define CSR_TVAL 13'h42
`define CSR_TICLR 13'h44
`define CSR_LLBCTL 13'h60
`define CSR_TLBRENTRY 13'h88
`define CSR_CTAG 13'h98
`define CSR_DMW0 13'h180
`define CSR_DMW1 13'h181



`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE  2
`define CSR_CRMD_DA  3
`define CSR_CRMD_PG  4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7

`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE  2

`define CSR_ESTAT_IS10 1:0
`define CSR_ESTAT_ECODE 21:16
`define CSR_ESTAT_ESUBCODE 30:22

`define CSR_ERA_PC 31:0

`define CSR_EENTRY_VA 31:6

`define CSR_SAVE_DATA 31:0

`define CSR_ECFG_LIE 12:0

`define CSR_BADV_ADDR 31:0

`define CSR_TID_TID 31:0

`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2

`define CSR_TICLR_CLR 0

// CSR Exception Code
`define ECODE_INT  6'h00
`define ECODE_PIL  6'h01
`define ECODE_PIS  6'h02
`define ECODE_PIF  6'h03
`define ECODE_PME  6'h04
`define ECODE_PPI  6'h07
`define ECODE_ADE  6'h08
`define ECODE_ALE  6'h09
`define ECODE_SYS  6'h0b
`define ECODE_BRK  6'h0c
`define ECODE_INE  6'h0d
`define ECODE_IPE  6'h0e
`define ECODE_FPD  6'h0f
`define ECODE_FPE  6'h12
`define ECODE_TLBR 6'h3f
`define ESUBCODE_ADEF 9'h00
`define ESUBCODE_ADEM 9'h01