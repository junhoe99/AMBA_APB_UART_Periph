`timescale 1ns / 1ps

module APB_Master (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    output logic [31:0] PADDR,
    output logic        PWRITE,
    output logic        PENABLE,
    output logic [31:0] PWDATA,
    // PSELs
    output logic        PSEL0,  // RAM
    output logic        PSEL1,  // GPO
    output logic        PSEL2,  // GPI
    output logic        PSEL3,  // GPIO
    output logic        PSEL4,  // UART
    // PRDATAs
    input  logic [31:0] PRDATA0,   // RAM
    input  logic [31:0] PRDATA1,   // GPO
    input  logic [31:0] PRDATA2,   // GPI
    input  logic [31:0] PRDATA3,   // GPIO
    input  logic [31:0] PRDATA4,   // UART
    // PREADYs
    input  logic        PREADY0,   // RAM
    input  logic        PREADY1,   // GPO
    input  logic        PREADY2,   // GPI
    input  logic        PREADY3,   // GPIO
    input  logic        PREADY4,   // UART
    // Internal Interface Signals
    input  logic        transfer,
    output logic        ready,
    input  logic        write,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);
    logic [4:0] pselx;
    logic [2:0] mux_sel;
    logic decoder_en;
    logic [31:0] temp_addr_reg, temp_addr_next, temp_wdata_reg, temp_wdata_next;
    logic temp_write_reg, temp_write_next;

    assign PSEL0 = pselx[0];
    assign PSEL1 = pselx[1];
    assign PSEL2 = pselx[2];
    assign PSEL3 = pselx[3];
    assign PSEL4 = pselx[4];

    typedef enum {
        IDLE,
        SETUP,
        ACCESS
    } apb_state_e;

    apb_state_e state, state_next;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            state          <= IDLE;
            temp_addr_reg  <= 0;
            temp_wdata_reg <= 0;
            temp_write_reg <= 0;
        end else begin
            state          <= state_next;
            temp_addr_reg  <= temp_addr_next;
            temp_wdata_reg <= temp_wdata_next;
            temp_write_reg <= temp_write_next;
        end
    end

    always_comb begin
        state_next      = state;
        decoder_en      = 1'b0;
        PENABLE         = 1'b0;
        temp_addr_next  = temp_addr_reg;
        temp_wdata_next = temp_wdata_reg;
        temp_write_next = temp_write_reg;
        PADDR           = temp_addr_reg;
        PWRITE          = temp_write_reg;
        PWDATA          = temp_wdata_reg;
        case (state)
            IDLE: begin
                decoder_en = 1'b0;
                if (transfer) begin
                    state_next = SETUP;
                    temp_addr_next = addr;  // latching
                    temp_wdata_next = wdata;
                    temp_write_next = write;
                end
            end
            SETUP: begin
                decoder_en = 1'b1;
                PENABLE    = 1'b0;
                PADDR      = temp_addr_reg;
                PWRITE     = temp_write_reg;
                state_next = ACCESS;
                if (temp_write_reg) begin
                    PWDATA = temp_wdata_reg;
                end
            end
            ACCESS: begin
                decoder_en = 1'b1;
                PENABLE    = 1'b1;
                if (ready) begin
                    state_next = IDLE;
                end
            end
        endcase
    end

    APB_Decoder U_APB_Decoder (
        .en     (decoder_en),
        .sel    (temp_addr_reg),
        .y      (pselx),
        .mux_sel(mux_sel)
    );

    APB_Mux U_APB_Mux (
        .sel   (mux_sel),
        .rdata0(PRDATA0),
        .rdata1(PRDATA1),
        .rdata2(PRDATA2),
        .rdata3(PRDATA3),
        .rdata4(PRDATA4), // UART read data
        .ready0(PREADY0),
        .ready1(PREADY1),
        .ready2(PREADY2),
        .ready3(PREADY3),
        .ready4(PREADY4), // UART ready
        .rdata (rdata),
        .ready (ready)
    );

endmodule

module APB_Decoder (
    input  logic        en,
    input  logic [31:0] sel,
    output logic [ 4:0] y,
    output logic [ 2:0] mux_sel
);
    always_comb begin
        y = 5'b00000;
        if (en) begin
            casex (sel)
                32'h1000_0xxx: y = 5'b00001;  // RAM
                32'h1000_1xxx: y = 5'b00010;  // GPO_Periph
                32'h1000_2xxx: y = 5'b00100;  // GPI_Periph
                32'h1000_3xxx: y = 5'b01000;  // GPIO_Periph
                32'h1000_4xxx: y = 5'b10000;  // UART_Periph
            endcase
        end
    end

    always_comb begin
        mux_sel = 3'dx;
        if (en) begin
            casex (sel)
                32'h1000_0xxx: mux_sel = 3'd0;  // RAM
                32'h1000_1xxx: mux_sel = 3'd1;  // GPO_Periph
                32'h1000_2xxx: mux_sel = 3'd2;  // GPI_Periph
                32'h1000_3xxx: mux_sel = 3'd3;  // GPIO_Periph
                32'h1000_4xxx: mux_sel = 3'd4;  // UART shares with GPIO
            endcase
        end
    end
endmodule

module APB_Mux (
    input  logic [ 2:0] sel,
    // read data
    input  logic [31:0] rdata0,   // RAM
    input  logic [31:0] rdata1,   // GPO
    input  logic [31:0] rdata2,   // GPI
    input  logic [31:0] rdata3,   // GPIO
    input  logic [31:0] rdata4,  // UART
    // ready signals
    input  logic        ready0,   // RAM
    input  logic        ready1,   // GPO
    input  logic        ready2,   // GPI
    input  logic        ready3,   // GPIO
    input  logic        ready4,   // UART
    // outputs
    output logic [31:0] rdata,
    output logic        ready
);

    always_comb begin
        rdata = 32'b0;
        case (sel)
            3'd0: rdata = rdata0;  // RAM read data
            3'd1: rdata = rdata1;  // GPO read data
            3'd2: rdata = rdata2;  // GPI read data
            3'd3: rdata = rdata3;  // GPIO read data
            3'd4: rdata = rdata4;  // UART read data
        endcase
    end

    always_comb begin
        ready = 1'b0;
        case (sel)
            3'd0: ready = ready0;  // RAM ready
            3'd1: ready = ready1;  // GPO ready
            3'd2: ready = ready2;  // GPI ready
            3'd3: ready = ready3;  // GPIO ready
            3'd4: ready = ready4;  // UART ready
        endcase
    end
endmodule
