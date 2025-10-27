`timescale 1ns / 1ps

module uart (
    input rst,
    input clk,
    input rx,  //수신 데이터 1비트씩
    input tx_start,  //송신 시작 키
    input [7:0] tx_data,  //송신할 데이터

    output       tx,       //송신 1비트씩
    output       tx_busy,  //송신중
    output       rx_busy,  ///수신중
    output       rx_done,  //수신 끝
    output [7:0] rx_data   //수신 받아온 데이터
);

    wire w_b_tick;  //baud_tick_gen 출력

    baud_tick_gen U_BAUD_TICK_GEN (  //100mhz -> 9600hz 틱생성
        .rst(rst),
        .clk(clk),
        .b_tick(w_b_tick)
    );

    uart_rx U_UART_RX (
        .rst(rst),
        .clk(clk),
        .b_tick(w_b_tick),
        .rx(rx),
        .rx_data(rx_data),
        .rx_busy(rx_busy),
        .rx_done(rx_done)
    );


    uart_tx U_UART_TX (  /// uart 전송
        .clk(clk),
        .rst(rst),
        .start(tx_start),
        .b_tick(w_b_tick),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx(tx)
    );



endmodule

module uart_rx (
    input rst,
    input clk,
    input rx,  //수신 데이터 1비트씩
    input b_tick,  // 보드율틱

    output [7:0] rx_data,  //수신 받아온 데이터
    output rx_busy,  ///수신중
    output rx_done  //수신 끝
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    reg [1:0] c_state, n_state;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;  // 틱 카운터
    reg [7:0]
        rx_data_reg,
        rx_data_next;  ///조합논리이기 때문에, 밖에서 assign으로 따로 출력과 연결. 래치방지
    reg [2:0] bit_cnt_reg, bit_cnt_next;  //데이터 비트 카운터
    reg rx_done_reg, rx_done_next;
    reg rx_busy_reg, rx_busy_next;

    assign rx_data = rx_data_reg;
    assign rx_busy = rx_busy_reg;
    assign rx_done = rx_done_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg <= 0;
            rx_data_reg <= 8'h0;
            rx_done_reg <= 1'b0;
            rx_busy_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            rx_data_reg <= rx_data_next;
            bit_cnt_reg <= bit_cnt_next;
            rx_done_reg <= rx_done_next;
            rx_busy_reg <= rx_busy_next;
        end
    end

    always @(*) begin

        n_state = c_state;  //초기화 
        b_tick_cnt_next = b_tick_cnt_reg;
        rx_data_next = rx_data_reg;
        bit_cnt_next = bit_cnt_reg;
        rx_done_next = rx_done_reg;
        rx_busy_next = rx_busy_reg;

        case (c_state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (~rx) begin  //rx 0가면 시작
                    n_state = START;
                    b_tick_cnt_next = 0;
                    bit_cnt_next = 0;
                    rx_busy_next = 1'b1;
                end
            end

            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        rx_data_next = {rx, rx_data_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                            bit_cnt_next = 0;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            n_state = DATA;
                        end
                    end else begin
                        n_state = DATA;
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = IDLE;
                        rx_done_next = 1'b1;
                        rx_busy_next = 1'b0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            default: n_state = IDLE;
        endcase
    end

endmodule




module uart_tx (  /// 
    input clk,
    input rst,
    input start,  //송신 시작 키
    input b_tick,
    input [7:0] tx_data,  //송신할 데이터

    output tx_busy,  //송신중
    output tx  //송신 1비트씩
);

    parameter IDLE = 0, WAIT = 1, START = 2, DATA_ST = 3, STOP = 4;
    reg [3:0] c_state, n_state;
    reg c_tx, n_tx;
    reg c_busy, n_busy;
    reg [2:0] c_bit_cnt, n_bit_cnt;
    reg [3:0] tick_cnt_reg, tick_cnt_next;
    reg [7:0] data_reg, data_next;

    assign tx = c_tx;
    assign tx_busy = c_busy;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            c_tx <= 1'b1;
            c_busy <= 1'b0;
            c_bit_cnt <= 0;
            tick_cnt_reg <= 4'h0;
            data_reg <= 8'h0;
        end else begin
            c_state <= n_state;
            c_tx <= n_tx;
            c_busy <= n_busy;
            c_bit_cnt <= n_bit_cnt;
            tick_cnt_reg <= tick_cnt_next;
            data_reg <= data_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        n_tx = c_tx;
        n_busy = c_busy;
        n_bit_cnt = c_bit_cnt;
        tick_cnt_next = tick_cnt_reg;
        data_next = data_reg;
        case (c_state)
            IDLE: begin
                n_tx = 1'b1;  ////moore out style
                n_busy = 1'b0;
                tick_cnt_next = 4'h0;
                if (start == 1'b1) begin
                    n_state = WAIT;
                    data_next = tx_data;  /// 한비트씩 밀기 위해 버퍼에 저장 
                end
            end
            WAIT: begin
                n_busy = 1'b1;
                if (b_tick == 1'b1) begin
                    n_state = START;
                end
            end
            START: begin
                n_tx = 1'b0;
                n_bit_cnt = 0;
                if (b_tick == 1'b1) begin
                    if (tick_cnt_reg == 15) begin
                        n_state = DATA_ST;
                        tick_cnt_next = 4'h0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end

                end
            end

            DATA_ST: begin
                n_tx = data_reg[0];
                if (b_tick) begin
                    if (tick_cnt_reg == 15) begin
                        data_next = data_reg >> 1;  //shift right
                        tick_cnt_next = 4'h0;
                        if (c_bit_cnt == 7) begin
                            n_state = STOP;
                        end else begin
                            n_bit_cnt = c_bit_cnt + 1;
                            n_state   = DATA_ST;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end

                end
            end

            STOP: begin
                n_tx = 1'b1;
                if (b_tick == 1'b1) begin
                    if (tick_cnt_reg == 15) begin
                        n_state = IDLE;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            default: n_state = c_state;
        endcase
    end
endmodule


module baud_tick_gen (  //100mhz -> 9600hz
    input  rst,
    input  clk,
    output b_tick
);

    parameter BAUD_COUNT = 100_000_000 / (9600 * 16);
    reg [$clog2(BAUD_COUNT)-1:0] tick_counter;
    reg r_tick;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            tick_counter <= 0;
            r_tick <= 0;
        end else begin
            if (tick_counter == BAUD_COUNT - 1) begin
                tick_counter <= 0;
                r_tick <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                r_tick <= 0;
            end
        end
    end
    assign b_tick = r_tick;
endmodule


/*
module uart_loopback (
    input  clk,
    input  rst,
    input  rx,
    output tx
);
    wire w_rx_done;
    wire [7:0] w_rx_data;

    uart U_UART (
        .rst(rst),
        .clk(clk),
        .rx(rx),  //수신 데이터 1비트씩
        .tx_start(w_rx_done),  //송신 시작 키
        .tx_data(w_rx_data),  //송신할 데이터

        .tx     (tx),         //송신 1비트씩
        .tx_busy(),           //송신중
        .rx_busy(),           ///수신중
        .rx_done(w_rx_done),  //수신 끝
        .rx_data(w_rx_data)   //수신 받아온 데이터
    );
endmodule
*/
