// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
// Date        : Fri Nov 28 17:47:29 2025
// Host        : jonathanxue running 64-bit Ubuntu 22.04.5 LTS
// Command     : write_verilog -force -mode funcsim -rename_top blk_mem_gen_0 -prefix
//               blk_mem_gen_0_ blk_mem_gen_0_sim_netlist.v
// Design      : blk_mem_gen_0
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "blk_mem_gen_0,blk_mem_gen_v8_4_11,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_11,Vivado 2025.1" *) 
(* NotValidForBitStream *)
module blk_mem_gen_0
   (clka,
    addra,
    douta);
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *) (* x_interface_mode = "slave BRAM_PORTA" *) (* x_interface_parameter = "XIL_INTERFACENAME BRAM_PORTA, MEM_ADDRESS_MODE BYTE_ADDRESS, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, MASTER_TYPE OTHER, READ_LATENCY 1" *) input clka;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *) input [8:0]addra;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *) output [31:0]douta;

  wire [8:0]addra;
  wire clka;
  wire [31:0]douta;
  wire NLW_U0_dbiterr_UNCONNECTED;
  wire NLW_U0_rsta_busy_UNCONNECTED;
  wire NLW_U0_rstb_busy_UNCONNECTED;
  wire NLW_U0_s_axi_arready_UNCONNECTED;
  wire NLW_U0_s_axi_awready_UNCONNECTED;
  wire NLW_U0_s_axi_bvalid_UNCONNECTED;
  wire NLW_U0_s_axi_dbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_rlast_UNCONNECTED;
  wire NLW_U0_s_axi_rvalid_UNCONNECTED;
  wire NLW_U0_s_axi_sbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_wready_UNCONNECTED;
  wire NLW_U0_sbiterr_UNCONNECTED;
  wire [31:0]NLW_U0_doutb_UNCONNECTED;
  wire [8:0]NLW_U0_rdaddrecc_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_bid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_bresp_UNCONNECTED;
  wire [8:0]NLW_U0_s_axi_rdaddrecc_UNCONNECTED;
  wire [31:0]NLW_U0_s_axi_rdata_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_rid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_rresp_UNCONNECTED;

  (* C_ADDRA_WIDTH = "9" *) 
  (* C_ADDRB_WIDTH = "9" *) 
  (* C_ALGORITHM = "1" *) 
  (* C_AXI_ID_WIDTH = "4" *) 
  (* C_AXI_SLAVE_TYPE = "0" *) 
  (* C_AXI_TYPE = "1" *) 
  (* C_BYTE_SIZE = "9" *) 
  (* C_COMMON_CLK = "0" *) 
  (* C_COUNT_18K_BRAM = "1" *) 
  (* C_COUNT_36K_BRAM = "0" *) 
  (* C_CTRL_ECC_ALGO = "NONE" *) 
  (* C_DEFAULT_DATA = "0" *) 
  (* C_DISABLE_WARN_BHV_COLL = "0" *) 
  (* C_DISABLE_WARN_BHV_RANGE = "0" *) 
  (* C_ELABORATION_DIR = "./" *) 
  (* C_ENABLE_32BIT_ADDRESS = "0" *) 
  (* C_EN_DEEPSLEEP_PIN = "0" *) 
  (* C_EN_ECC_PIPE = "0" *) 
  (* C_EN_RDADDRA_CHG = "0" *) 
  (* C_EN_RDADDRB_CHG = "0" *) 
  (* C_EN_SAFETY_CKT = "0" *) 
  (* C_EN_SHUTDOWN_PIN = "0" *) 
  (* C_EN_SLEEP_PIN = "0" *) 
  (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     3.375199 mW" *) 
  (* C_FAMILY = "artix7" *) 
  (* C_HAS_AXI_ID = "0" *) 
  (* C_HAS_ENA = "0" *) 
  (* C_HAS_ENB = "0" *) 
  (* C_HAS_INJECTERR = "0" *) 
  (* C_HAS_MEM_OUTPUT_REGS_A = "1" *) 
  (* C_HAS_MEM_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_A = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_REGCEA = "0" *) 
  (* C_HAS_REGCEB = "0" *) 
  (* C_HAS_RSTA = "0" *) 
  (* C_HAS_RSTB = "0" *) 
  (* C_HAS_SOFTECC_INPUT_REGS_A = "0" *) 
  (* C_HAS_SOFTECC_OUTPUT_REGS_B = "0" *) 
  (* C_INITA_VAL = "0" *) 
  (* C_INITB_VAL = "0" *) 
  (* C_INIT_FILE = "blk_mem_gen_0.mem" *) 
  (* C_INIT_FILE_NAME = "no_coe_file_loaded" *) 
  (* C_INTERFACE_TYPE = "0" *) 
  (* C_LOAD_INIT_FILE = "0" *) 
  (* C_MEM_TYPE = "3" *) 
  (* C_MUX_PIPELINE_STAGES = "0" *) 
  (* C_PRIM_TYPE = "1" *) 
  (* C_READ_DEPTH_A = "512" *) 
  (* C_READ_DEPTH_B = "512" *) 
  (* C_READ_LATENCY_A = "1" *) 
  (* C_READ_LATENCY_B = "1" *) 
  (* C_READ_WIDTH_A = "32" *) 
  (* C_READ_WIDTH_B = "32" *) 
  (* C_RSTRAM_A = "0" *) 
  (* C_RSTRAM_B = "0" *) 
  (* C_RST_PRIORITY_A = "CE" *) 
  (* C_RST_PRIORITY_B = "CE" *) 
  (* C_SIM_COLLISION_CHECK = "ALL" *) 
  (* C_USE_BRAM_BLOCK = "0" *) 
  (* C_USE_BYTE_WEA = "0" *) 
  (* C_USE_BYTE_WEB = "0" *) 
  (* C_USE_DEFAULT_DATA = "0" *) 
  (* C_USE_ECC = "0" *) 
  (* C_USE_SOFTECC = "0" *) 
  (* C_USE_URAM = "0" *) 
  (* C_WEA_WIDTH = "1" *) 
  (* C_WEB_WIDTH = "1" *) 
  (* C_WRITE_DEPTH_A = "512" *) 
  (* C_WRITE_DEPTH_B = "512" *) 
  (* C_WRITE_MODE_A = "WRITE_FIRST" *) 
  (* C_WRITE_MODE_B = "WRITE_FIRST" *) 
  (* C_WRITE_WIDTH_A = "32" *) 
  (* C_WRITE_WIDTH_B = "32" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  (* is_du_within_envelope = "true" *) 
  blk_mem_gen_0_blk_mem_gen_v8_4_11 U0
       (.addra(addra),
        .addrb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .clka(clka),
        .clkb(1'b0),
        .dbiterr(NLW_U0_dbiterr_UNCONNECTED),
        .deepsleep(1'b0),
        .dina({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .douta(douta),
        .doutb(NLW_U0_doutb_UNCONNECTED[31:0]),
        .eccpipece(1'b0),
        .ena(1'b0),
        .enb(1'b0),
        .injectdbiterr(1'b0),
        .injectsbiterr(1'b0),
        .rdaddrecc(NLW_U0_rdaddrecc_UNCONNECTED[8:0]),
        .regcea(1'b1),
        .regceb(1'b1),
        .rsta(1'b0),
        .rsta_busy(NLW_U0_rsta_busy_UNCONNECTED),
        .rstb(1'b0),
        .rstb_busy(NLW_U0_rstb_busy_UNCONNECTED),
        .s_aclk(1'b0),
        .s_aresetn(1'b0),
        .s_axi_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arburst({1'b0,1'b0}),
        .s_axi_arid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arready(NLW_U0_s_axi_arready_UNCONNECTED),
        .s_axi_arsize({1'b0,1'b0,1'b0}),
        .s_axi_arvalid(1'b0),
        .s_axi_awaddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awburst({1'b0,1'b0}),
        .s_axi_awid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awready(NLW_U0_s_axi_awready_UNCONNECTED),
        .s_axi_awsize({1'b0,1'b0,1'b0}),
        .s_axi_awvalid(1'b0),
        .s_axi_bid(NLW_U0_s_axi_bid_UNCONNECTED[3:0]),
        .s_axi_bready(1'b0),
        .s_axi_bresp(NLW_U0_s_axi_bresp_UNCONNECTED[1:0]),
        .s_axi_bvalid(NLW_U0_s_axi_bvalid_UNCONNECTED),
        .s_axi_dbiterr(NLW_U0_s_axi_dbiterr_UNCONNECTED),
        .s_axi_injectdbiterr(1'b0),
        .s_axi_injectsbiterr(1'b0),
        .s_axi_rdaddrecc(NLW_U0_s_axi_rdaddrecc_UNCONNECTED[8:0]),
        .s_axi_rdata(NLW_U0_s_axi_rdata_UNCONNECTED[31:0]),
        .s_axi_rid(NLW_U0_s_axi_rid_UNCONNECTED[3:0]),
        .s_axi_rlast(NLW_U0_s_axi_rlast_UNCONNECTED),
        .s_axi_rready(1'b0),
        .s_axi_rresp(NLW_U0_s_axi_rresp_UNCONNECTED[1:0]),
        .s_axi_rvalid(NLW_U0_s_axi_rvalid_UNCONNECTED),
        .s_axi_sbiterr(NLW_U0_s_axi_sbiterr_UNCONNECTED),
        .s_axi_wdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_wlast(1'b0),
        .s_axi_wready(NLW_U0_s_axi_wready_UNCONNECTED),
        .s_axi_wstrb(1'b0),
        .s_axi_wvalid(1'b0),
        .sbiterr(NLW_U0_sbiterr_UNCONNECTED),
        .shutdown(1'b0),
        .sleep(1'b0),
        .wea(1'b0),
        .web(1'b0));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2025.1"
`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
gydSV72FvW4hnoyUt6yZFJHfJqjRQWPUfYIuDKP0fpjrPOkLRbJGBr4Z9msYTvoIHRlYtXJ2YMY0
d1TIQb+FK4gKsTRru9wr397OxuFBsTRf4e+ZjpYZEdsnqYWcgMSzhN4yhPvO06GyZO15y/LKBxa8
3OKwxVlOLYXhv+sxdXg=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
WHB6Zbfa5Qi47krP9T4L8UnPOlr881dWx7UcYaZfNGIQQM0gadcoXbhucIpRaUuyOKxv6yhKveRN
h0l+N9+KX6rbZ6+TRhP9JAMuPhlpI7T42QtRv5zx9+m3ct5S0NMszbFaK8zeTAYra5BGP7BHmtkr
MpKfLK5sFyaTE/A7ACtAace9MwFTHDZdl9uUs4aY6KJlm6GaypKduiqkNugukJp5vlFPX/ZapJqG
KMtMhI6grhcuYb1FJrwRZ4jW7hs9HxddSdGLzsZ0HsBcO/qaCPTst+ZA0YIQfd5ULlFmPqq39FfO
p1P+2hEH2n+LycbMj5cn4Dxfqv2R8eucM78R3w==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
SmAzQA1VEuJXtJi5vXa2Jg7YvRqAJs6PX9HTZ1YqrJw4VfonBW3726gJ81BjlizpMkcf/Uk5sFIK
aPedVhEs4xCIZylz7gXYDshtytOA/pXUID2qV9nXr8qfI+FydSADUF3ScYDZmlkclFqlZrGq6DQ7
da3lJAzt2h/iR+cczrA=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
iAph5JWb/chMQpLPX1UoLjQDxN5l2I8McM/k2xN5wRht7HXoE6F5yV8luDjn3zkI6vnfUYo7BaI1
mogRRx+R3XcwxvhHr+lngh4+/YLVex1TFncl+kiUMAsu3M/FjFSiqGMVMdKTNLDqr35DuZJVyuiF
lTwXob/KkbQDJiJjBEoxbt+968rKRKRyJGcqIjm4mqRBdqMcgo3HOJFG74SFsWAQrxvXfBhdLSG3
OfoLfls9XDojBjp7G83k0h82g1eeWgBfydm/OcX9o48Pst93NvI4ua8WShZL8MCvRWYqWZrrjrWi
cfUjXAF5SDACjq1/OU6arz/Idz6/a7AP/jmexw==

`pragma protect key_keyowner="Real Intent", key_keyname="RI-RSA-KEY-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
BY49GZBxBT/gjZDPyaSWlti/sctckoR7jK6NuWdhnF9tiyNfVU7BqjjwxSnyMi0Uucv1BKHXC18h
8hQbFWnNtrq71ilURotXux7sssHlVJ2i1CsJWU18DOcBWxm2ai89uwvxDJh3TJkBJixB5KPvsDhL
lWOjTvZWPoR+Ixy+Tzo+U5Vx7z7SOakRwTrn3u7+c3vmCEBphE+HKeJExhBAoOEd0SXK5iwXaByW
D7Wb7zq6NNUmnCyaJ2BG9kGxLVsf+md7SlocuaFsYyaRZhwPyTucxIlz1tLYwcytKzx0ovoax3no
nYgzlzP/F0/PDWk9BqXgr/tuclc4EZYX0cf4ng==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2025.1-2029.x", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
qGnCvL35qO7cbUEKCL50yDv1UvezcqBz601zctKop1954QlcjemzZWZHg1zJ00nJaToNdH2S8AKX
n8hNJvbQ+x5HEGL5DoSU9m5qjXd8xxocnZ0yzuZX/dGCT8kDn3gWJR2Gz13pT+w2LQUno1fX+MsC
ehgwvjBBT6GeYjdxHi+aybQUP9AblSxX/z3vh857SGCPohEWvghOgORCHAe45YD+ZWnL62FLxMM2
c+Ozq/Au/Q4q1Yzlzcfv8Mnsvg7OqOeEamQHbuYOfdkJUuYqOwsskEWW348u7FXtsf8m7P3pZyyz
IWyTDAW4igGguMPLHfbtK/twZx8ScJQmOKzglg==

`pragma protect key_keyowner="Metrics Technologies Inc.", key_keyname="DSim", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Hz+6K8+wh5/fukU4ZWNDXGsq6hreSVCSPP67nA6kUz9Vpjy4TtTnOrrl1BWY0ivEC7Ldyw8VI60A
VO/WPlt409LdAZdMZGsEZ1JuTZ0m9LPcgu9CPCyoMECctmd8LHE+otY6etTmYABB9syY61rk2hrv
RgbcyT/HCK9TzWxSm+XMqvx2nvagCLkMDPh/JZv51fj2zcKaBPnxsz8rnDipaeo0fEyVRC3Y1F/V
U3RmXojBjIumPHSJkQ537dENJEIA0Ra65u8EM/+ItUn1bcryLcIbKy1xGadrHmHdHRUoRcAodO2C
B48bNVeL0VnGg8P9ACIB04lMNzn5p6A1tPOb4Q==

`pragma protect key_keyowner="Atrenta", key_keyname="ATR-SG-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=384)
`pragma protect key_block
YDpb+UeT0rJ543Q8wCo2xSS3gpVAT+JoStgBlV5IMjJoUOWkiOPn691FGChmDi3BTq5NxC73KHHR
1galACCjeTGq6cv+0Zc2Ocm1oobdrnSPHp7TMDr5Zle8FX6WywJCiGdoWBODggZSlbOASIK/PVfY
cZM2z60M6RSvzsi3TnYHiKYHpju8THVoSgRd6r31GcbiSy9TjjARERXan0OVc79jGuAg90mmDEEq
91eqmn6NZ9yLI2fgBjFUZbtFCpmJ8WGxOL1h39niWnRK3ZXnk8jcpnZUlxLbYTPO0Z3vVr1zrvcn
RVQloU0OLqg7M95zSs7NtX5Vzvb6jGbMehWV+WMMyxWmxL2XOwsAwPSeX2dI2r77pioY7X6VzH7f
/JxMAnq9udra3WGPsUkD1G0CvPkCC3zdxjpVaflY37ztX9UONhKtzMQa8lJc1IL8GhXRY3R9Lg2c
HIeXSGkpNNuFDqKT6Khe/6Casq+SjFJq+IH9IUtz6RUZTkbFb0Xhgm2P

`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="CDS_RSA_KEY_VER_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Q+63zFEYw/LeMgxa7g8g79GGvSyIKDKD8RvvC4DHDQuGObf6n9OGZX4e17v/E/+EDEwUhsWQHFDI
Lp/aH+6fNRmhu9BEWVjxq2WRrQSl4eQjfIaSOXu2dlYh3JjRJwiUp4LteVh8RFAf5t5sRQO4dRIK
x+h28yliSgibaWEAv5FaJQ1EFbNwmgedAaSYjgf2A3afBUcBh5Uy9VHbW/zRzdhhJdsVNBjZYcFy
CVLOcf1toCRp8J4U5FlnFMOzFegUbdXFQhq2VmIhPRxWjrfTk6iR4BcMEN9UMij/5IHRAeBdksyD
CqEKsyFxosbI5KVMRZ1Ln75Zipn0JdsGekHkxg==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
DPUa5DLPYRWvbPnX0U412yoWvvvHyuq43DrYmDJGTK0cR5U4U6th8icYgizC1/hUAEzt19kM/hVa
zZh7bXSWACYLpcfhPY8dRTVGDZVjpbkraw0ceBryLP7jc6Jt5JdNw88tZtZpprCB7nQ25lUL82Hf
WTwL1ZqgGIvtfHhxO0JF5L5ES5giedwQ6u5ffXG3UB6ELcpQD1NvpW5lAz4mfXyvVDCAPZN581TF
tlAy79iKbPKlJ2zFn1BS2cuRIHHe2JRxwPo+0n5VD5CXVgg+lCYxTnCxI8CdyFaTumbs4IfAKwVI
wSN/btbwDUhW9hAHWHIRo+BpdJ4qeGcTDPKtsA==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-PREC-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
mf5hcf6JE6yLm0jNCQnHMVmogjLlPz6re0FwG67yvOJ3FuEorru0emIeAKEwgOoxjUYNWvcM7QAH
/UEeB2EIdjLl6glPAUda0HjtaCU2rdncVdM8k6DSMBggc4yo18Qx5F+1TD/RoBgoo0jNkMdDy6wJ
JHjqlN+R01z3yYIMQ9f2z6ZaYncbBYEp4+YAb7g1D7CSMxP5cFRpQznRpYp0JwqJfT9CHzlKgdab
8B288NxeLM66iYodiTS+GSRGLGtDWXpz9yeiuiPe6kJxae2GJyHIMSfluO/0Slc3m24DQNdbojf8
jdc0G2UnrDe5mCUTfYiDmpOWTUJOdYo0FK0N2g==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 18688)
`pragma protect data_block
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
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
