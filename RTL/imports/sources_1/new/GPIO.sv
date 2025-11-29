`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/24 10:44:14
// Design Name: 
// Module Name: GPIO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module GPIO_Periph (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [31:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // External Port
    inout logic [ 7:0] gpio
);

    // Internal Ports
    logic [7:0] cr;
    logic [7:0] odr;
    logic [7:0] idr; 

    APB_SlaveIntf_GPIO U_APB_SlaveInterf_GPIO (.*);
    GPIO U_GPIO (.*);
endmodule


module APB_SlaveIntf_GPIO (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [31:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // I/O Port
    output logic [ 7:0] cr,       // control register
    output logic [ 7:0] odr,      // output data register
    input  logic [ 7:0] idr       // input data register    
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2;
    // slv_reg0 : cr
    // slv_reg1 : odr
    // slv_reg2 : idr (read only)

    assign cr = slv_reg0[7:0];
    assign odr = slv_reg1[7:0];


    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            //slv_reg3 <= 0;
        end else begin
            PREADY <= 1'b0;
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                // write operation
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;  // address : 0x0
                        2'd1:
                        slv_reg1 <= PWDATA;  
                        2'd2: ;                // idr(slv_reg2)은 read only이므로, 쓰기 불가
                        2'd3: ;
                    endcase
                end else begin
                    // read operation
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;   // address : 0x0
                        2'd1: PRDATA <= slv_reg1;   // address : 0x4
                        2'd2: PRDATA <= {24'b0, idr}; // address : 0x8
                        2'd3: ;
                    endcase

                end
            end
        end
    end
endmodule


module GPIO(
    input  logic [7:0] cr,      // slv_reg0 -> GPIO
    input  logic [7:0] odr,     // slv_reg1 -> GPIO -> MCU Outport
    output  logic [7:0] idr,    // MCU Input Port -> GPIO -> slv_reg2
    inout logic [7:0] gpio
);


    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign gpio[i] = cr[i] ? odr[i] : 1'bz;
            assign idr[i] = (~cr[i]) ? gpio[i] : 1'bz;
        end
    endgenerate

    //assign gpio[0] = cr[0] ? odr[0] : 1'bz;    
    // cr == 1이면, output mode이므로, gpio = odr
    // cr == 0이면, input  mode이므로, gpio = high-Z
endmodule