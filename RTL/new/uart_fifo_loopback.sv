`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/21 11:58:24
// Design Name: 
// Module Name: uart_fifo_loopback
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

module UART_Periph(
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [31:0] PADDR,  // Changed to match APB_Master output
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // External UART Port
    input  logic        rx,
    output logic        tx
);

    // Register-based control signals between APB interface and UART
    logic        uart_enable;
    logic        uart_tx_start;
    logic [7:0]  uart_tx_data;
    logic        uart_tx_busy;
    logic        uart_rx_busy;
    logic        uart_rx_done;
    logic [7:0]  uart_rx_data;

    // APB Slave Interface - Standard Memory Mapped I/O
    APB_SlaveIntf_UART U_APB_SlaveIntf_UART (
        .PCLK(PCLK),
        .PRESET(PRESET),
        .PSEL(PSEL),
        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PENABLE(PENABLE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        // Register-based UART control
        .uart_enable(uart_enable),
        .uart_tx_start(uart_tx_start),
        .uart_tx_data(uart_tx_data),
        .uart_tx_busy(uart_tx_busy),
        .uart_rx_busy(uart_rx_busy),
        .uart_rx_done(uart_rx_done),
        .uart_rx_data(uart_rx_data)
    );

    // UART with FIFO and Loopback functionality
    // This can operate in two modes:
    // 1. Auto-loopback mode (hardware controlled)
    // 2. CPU-controlled mode (via APB registers)
    uart_fifo_loopback U_UART (
        .clk(PCLK),
        .rst(PRESET),
        .enable(uart_enable),
        .rx(rx),
        .tx(tx),
        // CPU control interface (register-based)
        .cpu_tx_start(uart_tx_start),
        .cpu_tx_data(uart_tx_data),
        .cpu_tx_busy(uart_tx_busy),
        .cpu_rx_busy(uart_rx_busy),
        .cpu_rx_done(uart_rx_done),
        .cpu_rx_data(uart_rx_data)
    );

endmodule


module APB_SlaveIntf_UART(
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic        PSEL,
    input  logic [31:0] PADDR,  // Changed to match APB_Master output
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // UART Control Interface (Register-based, following AMBA APB standard)
    output logic        uart_enable,
    output logic        uart_tx_start,
    output logic [7:0]  uart_tx_data,
    input  logic        uart_tx_busy,
    input  logic        uart_rx_busy,
    input  logic        uart_rx_done,
    input  logic [7:0]  uart_rx_data
    // Note: External UART pins are connected directly in UART_Periph
);
    // Standard UART Register Map (Memory Mapped I/O)
    // 0x00: Control Register   - bit[0]: UART Enable
    // 0x04: Status Register    - bit[0]: TX Busy, bit[1]: RX Busy, bit[2]: RX Done
    // 0x08: TX Data Register   - Write triggers transmission
    // 0x0C: RX Data Register   - Read received data
    
    logic [31:0] ctrl_reg;      // Control register
    logic [31:0] status_reg;    // Status register (read-only)
    logic [31:0] tx_data_reg;   // TX data register
    logic [31:0] rx_data_reg;   // RX data register (read-only)
    
    logic tx_start_pulse, tx_start_prev;
    logic rx_done_latch;        // Latch rx_done until CPU reads it
    
    // Control signal assignments
    assign uart_enable = ctrl_reg[0];
    assign uart_tx_data = tx_data_reg[7:0];
    
    // Status register (hardware controlled) - use latched rx_done
    assign status_reg = {29'b0, rx_done_latch, uart_rx_busy, uart_tx_busy};
    assign rx_data_reg = {24'b0, uart_rx_data};
    
    // Latch rx_done signal until CPU reads RX data
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            rx_done_latch <= 1'b0;
        end else begin
            if (uart_rx_done) begin
                rx_done_latch <= 1'b1;  // Set when data received
            end else if (PSEL && PENABLE && !PWRITE && (PADDR[3:2] == 2'b11)) begin
                rx_done_latch <= 1'b0;  // Clear when CPU reads RX data register
            end
        end
    end
    
    // Generate single pulse for TX start (edge detection)
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            tx_start_prev <= 1'b0;
        end else begin
            tx_start_prev <= tx_start_pulse;
        end
    end
    assign uart_tx_start = tx_start_pulse & ~tx_start_prev;

    // APB Slave Register Interface (Standard Memory Mapped I/O)
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            ctrl_reg <= 32'h00000001;  // Default: UART enabled
            tx_data_reg <= 32'b0;
            tx_start_pulse <= 1'b0;
            PREADY <= 1'b0;
            PRDATA <= 32'b0;
        end else begin
            PREADY <= 1'b0;
            tx_start_pulse <= 1'b0;
            
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                
                if (PWRITE) begin
                    // Memory Mapped Write Operations
                    case (PADDR[3:2])
                        2'b00: ctrl_reg <= PWDATA;        // 0x00: Control Register
                        2'b01: ;                           // 0x04: Status Register (Read-Only)
                        2'b10: begin                       // 0x08: TX Data Register
                            tx_data_reg <= PWDATA;
                            tx_start_pulse <= 1'b1;       // Auto-trigger transmission
                        end
                        2'b11: ;                           // 0x0C: RX Data Register (Read-Only)
                    endcase
                end else begin
                    // Memory Mapped Read Operations
                    case (PADDR[3:2])
                        2'b00: PRDATA <= ctrl_reg;        // 0x00: Control Register
                        2'b01: PRDATA <= status_reg;      // 0x04: Status Register
                        2'b10: PRDATA <= tx_data_reg;     // 0x08: TX Data Register
                        2'b11: PRDATA <= rx_data_reg;     // 0x0C: RX Data Register
                    endcase
                end
            end
        end
    end 
endmodule


module uart_fifo_loopback(
    input clk,
    input rst,
    input enable,
    input rx,
    output tx,
    // CPU Interface (for direct CPU control when needed)
    input        cpu_tx_start,
    input [7:0]  cpu_tx_data,
    output       cpu_tx_busy,
    output       cpu_rx_busy,
    output       cpu_rx_done,
    output [7:0] cpu_rx_data
);

    // Internal UART signals
    wire w_rx_done, w_tx_busy, w_tx_start, w_lp_push, w_lp_pop;
    wire [7:0] w_rx_data, w_tx_data, w_loop_back_data;
    
    // CPU control signals
    wire use_cpu_control;
    wire final_tx_start;
    wire [7:0] final_tx_data;
    
    // Determine control source: CPU has priority over loopback
    assign use_cpu_control = cpu_tx_start;
    assign final_tx_start = use_cpu_control ? cpu_tx_start : ~w_tx_start;
    assign final_tx_data = use_cpu_control ? cpu_tx_data : w_tx_data;
    
    // Connect CPU interface signals
    assign cpu_tx_busy = w_tx_busy;
    assign cpu_rx_busy = 1'b0; // UART RX busy not directly exposed in current UART
    assign cpu_rx_done = w_rx_done;
    assign cpu_rx_data = w_rx_data;

    uart U_UART(
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx_data(final_tx_data),
        .tx_start(final_tx_start),
        .tx(tx),
        .tx_busy(w_tx_busy),
        .rx_busy(),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );

    // Loopback FIFOs (only active when CPU is not controlling)
    fifo U_UART_TX_FIFO(
        .clk(clk),
        .rst(rst),
        .w_data(w_loop_back_data),
        .push(~w_lp_push && !use_cpu_control),
        .pop(~w_tx_busy && !use_cpu_control),
        .r_data(w_tx_data),
        .full(w_lp_pop),
        .empty(w_tx_start)
    );

    fifo U_UART_RX_FIFO(
        .clk(clk),
        .rst(rst),
        .w_data(w_rx_data),
        .push(w_rx_done && !use_cpu_control),
        .pop(~w_lp_pop && !use_cpu_control),
        .r_data(w_loop_back_data),
        .full(),
        .empty(w_lp_push)
    );
    
endmodule


module fifo(
    input clk,
    input rst,
    input [7:0] w_data,
    input push,
    input pop,
    output [7:0] r_data,
    output full,
    output empty
    );

    wire [1:0] w_w_addr;
    wire [1:0] w_r_addr;

    register_file REG_FILE(
        .clk(clk),
        .w_data(w_data),
        .w_addr(w_w_addr),
        .r_addr(w_r_addr),
        .wr_en(~(full)&push),
        .r_data(r_data)
    );

    fifo_control_unit FIFO_CNTRL_UNIT(
        .clk(clk),
        .rst(rst),
        .push(push),
        .pop(pop),
        .full(full),
        .empty(empty),
        .w_addr(w_w_addr),
        .r_addr(w_r_addr)
    );

endmodule

module register_file(
    input clk,
    input [7:0] w_data,
    input [1:0] w_addr,
    input [1:0] r_addr,
    input wr_en,
    output [7:0] r_data
    );

    reg [7:0] mem[0:3];

    always@(posedge clk)begin
        if(wr_en)begin
            //Write op.
            mem[w_addr] <= w_data;  //w_addr : 총 8bit의 w_data를 write하기 위해 사용되는 addr indicator용 signal
        end
    end

    assign r_data = mem[r_addr];  // r_addr : read 동작시 read할 bit수를 특정하기 위해 사용되는 addr indicator용 signal
endmodule



module fifo_control_unit(
    input clk,
    input rst,
    input push,
    input pop,
    output full,
    output empty,
    output [1:0] w_addr,
    output [1:0] r_addr
    );

    reg[1:0] wptr_reg, wptr_next;
    reg[1:0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;



    //State Register(Feedback Structure)
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            wptr_reg <= 0;
            rptr_reg <= 0;
            full_reg <= 0;
            empty_reg <= 1;
        end
        else begin
            wptr_reg <= wptr_next;
            rptr_reg <= rptr_next;
            full_reg <= full_next;
            empty_reg <= empty_next;
        end
    end


    //Combiational Logic
    always@(*)begin
            wptr_next = wptr_reg;
            rptr_next = rptr_reg;
            full_next = full_reg;
            empty_next = empty_reg;
        case({push, pop})
            2'b01 : begin // POP
                if(!empty_reg)begin //FIFO에 data가 하나라도 있다면, read(POP)동작 수행
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                    if(rptr_next == wptr_reg) begin // read pointer가 write pointer에 도달했다면, FIFO가 empty인 상태
                        empty_next = 1;
                    end
                end
            end

            2'b10 : begin //PUSH
                if(!full_reg)begin    // FIFO가 하나라도 비어있다면, write(PUSH)동작 수행
                    wptr_next = wptr_reg + 1;
                    empty_next = 1'b0;
                    if(wptr_next == rptr_reg)begin  //write pointer가 read pointer에 도달했다면, FIFO가 full상태
                        full_next = 1'b1;
                    end
                end
            end

            2'b11 : begin  //PUSH, POP inserted simultaneously
                if(empty_reg)begin
                    wptr_next = wptr_reg + 1;
                    empty_next = 1'b0;
                end
                else if(full_reg)begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end
    assign w_addr = wptr_reg;
    assign r_addr = rptr_reg;
    assign full = full_reg;
    assign empty = empty_reg;
    
endmodule