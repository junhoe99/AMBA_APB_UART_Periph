`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/24 09:45:49
// Design Name: 
// Module Name: GPI
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


module GPI_Periph (
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
    input  logic [ 7:0] gpi
);

    logic [7:0] cr;
    logic [7:0] idr;  // 내부 신호로 변경

    APB_SlaveIntf_GPI U_APB_SlaveInterf_GPI (.*);
    GPI U_GPI (.*);
endmodule


module APB_SlaveIntf_GPI (
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
    // Internal Port
    output logic [ 7:0] cr,       // control register
    input  logic [ 7:0] idr       // input data register
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;

    assign cr = slv_reg0[7:0];
    //assign slv_reg1 = {24'd0, idr};  // idr is read-only



    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            //slv_reg2 <= 0;
            //slv_reg3 <= 0;
        end else begin
            PREADY <= 1'b0;
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[2:2])
                        1'd0: slv_reg0 <= PWDATA;  // address : 0x0
                        //1'd1: slv_reg1 <= PWDATA;  // idr은 read only이므로, 쓰기 불가
                        //2'd2: slv_reg2 <= PWDATA;
                        //2'd3: slv_reg3 <= PWDATA;
                    endcase
                end else begin
                    case (PADDR[2:2])
                        1'd0: PRDATA <= slv_reg0;
                        1'd1: PRDATA <= idr;
                        //2'd2: PRDATA <= slv_reg2;
                        //2'd3: PRDATA <= slv_reg3;
                    endcase

                end
            end
        end
    end
endmodule


module GPI (
    input  logic [7:0] cr,
    output logic [7:0] idr,
    input  logic [7:0] gpi
);

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign idr[i] = (cr[i]) ? gpi[i] : 8'bz;
        end
    endgenerate
endmodule




