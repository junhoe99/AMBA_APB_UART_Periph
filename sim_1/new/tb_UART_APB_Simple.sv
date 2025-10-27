`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/26 14:00:00
// Design Name: 
// Module Name: tb_UART_APB_Simple
// Project Name: AMBA_APB_UART
// Target Devices: 
// Tool Versions: 
// Description: 
//   Comprehensive testbench for UART_Periph verification
//   Tests both UART loopback functionality and APB read operations
//   Includes APB_Manager, uart_sender, and uart_receiver modules
// 
// Dependencies: 
//   - UART_Periph.sv (DUT)
//   - APB_Master.sv
//   - UART.sv
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//   Verifies two main scenarios:
//   1. UART loopback: uart_sender -> DUT -> uart_receiver data comparison
//   2. APB read: UART RX data accessible via APB PRDATA
//////////////////////////////////////////////////////////////////////////////////

module tb_UART_APB_Simple();

    //////////////////////////////////////////////////////////////////////////
    // Parameters and Constants
    //////////////////////////////////////////////////////////////////////////
    parameter CLK_PERIOD = 10;          // 100MHz clock
    parameter BAUD_RATE = 9600;
    parameter BAUD_PERIOD = 1000000000 / BAUD_RATE;  // ~104166 ns
    parameter UART_BIT_PERIOD = BAUD_PERIOD;

    // APB Address Map (matching APB_Master decoder)
    parameter UART_BASE_ADDR = 32'h10004000;
    parameter CTRL_REG_ADDR  = UART_BASE_ADDR + 32'h00;
    parameter STATUS_REG_ADDR= UART_BASE_ADDR + 32'h04;
    parameter TX_REG_ADDR    = UART_BASE_ADDR + 32'h08;
    parameter RX_REG_ADDR    = UART_BASE_ADDR + 32'h0C;

    //////////////////////////////////////////////////////////////////////////
    // Global Signals
    //////////////////////////////////////////////////////////////////////////
    logic        PCLK;
    logic        PRESET;

    //////////////////////////////////////////////////////////////////////////
    // APB Interface Signals (CPU side to APB_Manager)
    //////////////////////////////////////////////////////////////////////////
    logic        transfer;
    logic        ready;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    //////////////////////////////////////////////////////////////////////////
    // APB Interface Signals (APB_Manager to peripherals)
    //////////////////////////////////////////////////////////////////////////
    logic [31:0] PADDR;
    logic        PWRITE;
    logic        PENABLE;
    logic [31:0] PWDATA;
    logic        PSEL0, PSEL1, PSEL2, PSEL3, PSEL4;  // UART uses PSEL4
    logic [31:0] PRDATA0, PRDATA1, PRDATA2, PRDATA3, PRDATA4;  // UART uses PRDATA4
    logic        PREADY0, PREADY1, PREADY2, PREADY3, PREADY4;   // UART uses PREADY4

    //////////////////////////////////////////////////////////////////////////
    // UART Interface Signals
    //////////////////////////////////////////////////////////////////////////
    logic        uart_rx_to_dut;     // From uart_sender to DUT
    logic        uart_tx_from_dut;   // From DUT to uart_receiver

    //////////////////////////////////////////////////////////////////////////
    // Debug and Monitoring Signals (for waveform analysis)
    //////////////////////////////////////////////////////////////////////////
    
    // DUT Internal Signals (for debugging - connect to DUT internals)
    logic        dut_uart_enable;
    logic        dut_uart_tx_start;
    logic [7:0]  dut_uart_tx_data;
    logic        dut_uart_tx_busy;
    logic        dut_uart_rx_busy;
    logic        dut_uart_rx_done;
    logic [7:0]  dut_uart_rx_data;
    
    // Assign DUT internal signals for monitoring
    assign dut_uart_enable   = dut_uart_periph.uart_enable;
    assign dut_uart_tx_start = dut_uart_periph.uart_tx_start;
    assign dut_uart_tx_data  = dut_uart_periph.uart_tx_data;
    assign dut_uart_tx_busy  = dut_uart_periph.uart_tx_busy;
    assign dut_uart_rx_busy  = dut_uart_periph.uart_rx_busy;
    assign dut_uart_rx_done  = dut_uart_periph.uart_rx_done;
    assign dut_uart_rx_data  = dut_uart_periph.uart_rx_data;

    //////////////////////////////////////////////////////////////////////////
    // Testbench Control Signals
    //////////////////////////////////////////////////////////////////////////
    logic [7:0]  tx_test_data;       // Data to send via uart_sender
    logic        tx_start;           // Start transmission
    logic        tx_busy;            // uart_sender busy
    logic [7:0]  rx_received_data;   // Data received by uart_receiver
    logic        rx_done;            // Reception complete
    logic        rx_busy;            // uart_receiver busy

    //////////////////////////////////////////////////////////////////////////
    // DUT Instance: UART_Periph
    //////////////////////////////////////////////////////////////////////////
    UART_Periph dut_uart_periph (
        // Global signals
        .PCLK    (PCLK),
        .PRESET  (PRESET),
        // APB Interface Signals
        .PADDR   (PADDR),
        .PWRITE  (PWRITE),
        .PENABLE (PENABLE),
        .PWDATA  (PWDATA),
        .PSEL    (PSEL4),           // UART peripheral selection
        .PRDATA  (PRDATA4),         // UART read data
        .PREADY  (PREADY4),         // UART ready signal
        // External UART Port
        .rx      (uart_rx_to_dut),
        .tx      (uart_tx_from_dut)
    );

    //////////////////////////////////////////////////////////////////////////
    // APB_Manager Instance (renamed from APB_Master for clarity)
    //////////////////////////////////////////////////////////////////////////
    APB_Master apb_manager (
        // Global signals
        .PCLK    (PCLK),
        .PRESET  (PRESET),
        // APB Interface Signals
        .PADDR   (PADDR),
        .PWRITE  (PWRITE),
        .PENABLE (PENABLE),
        .PWDATA  (PWDATA),
        // Peripheral select signals
        .PSEL0   (PSEL0),           // RAM (not used in this TB)
        .PSEL1   (PSEL1),           // GPO (not used in this TB)
        .PSEL2   (PSEL2),           // GPI (not used in this TB)
        .PSEL3   (PSEL3),           // GPIO (not used in this TB)
        .PSEL4   (PSEL4),           // UART peripheral
        // Peripheral read data
        .PRDATA0 (PRDATA0),         // RAM (tied to 0)
        .PRDATA1 (PRDATA1),         // GPO (tied to 0)
        .PRDATA2 (PRDATA2),         // GPI (tied to 0)
        .PRDATA3 (PRDATA3),         // GPIO (tied to 0)
        .PRDATA4 (PRDATA4),         // UART peripheral
        // Peripheral ready signals
        .PREADY0 (PREADY0),         // RAM (tied to 1)
        .PREADY1 (PREADY1),         // GPO (tied to 1)
        .PREADY2 (PREADY2),         // GPI (tied to 1)
        .PREADY3 (PREADY3),         // GPIO (tied to 1)
        .PREADY4 (PREADY4),         // UART peripheral
        // Internal Interface Signals (CPU interface)
        .transfer(transfer),
        .ready   (ready),
        .write   (write),
        .addr    (addr),
        .wdata   (wdata),
        .rdata   (rdata)
    );

    //////////////////////////////////////////////////////////////////////////
    // APB_UART Module: Contains uart_sender and uart_receiver
    //////////////////////////////////////////////////////////////////////////
    APB_UART apb_uart_inst (
        .clk               (PCLK),
        .reset             (PRESET),
        // UART connection to DUT
        .uart_tx_to_dut    (uart_rx_to_dut),     // Our TX becomes DUT's RX
        .uart_rx_from_dut  (uart_tx_from_dut),   // DUT's TX becomes our RX
        // Control interface
        .tx_data           (tx_test_data),
        .tx_start          (tx_start),
        .tx_busy           (tx_busy),
        .rx_data           (rx_received_data),
        .rx_done           (rx_done),
        .rx_busy           (rx_busy)
    );

    //////////////////////////////////////////////////////////////////////////
    // Tie off unused peripheral signals
    //////////////////////////////////////////////////////////////////////////
    assign PRDATA0 = 32'h0;
    assign PRDATA1 = 32'h0;
    assign PRDATA2 = 32'h0;
    assign PRDATA3 = 32'h0;
    assign PREADY0 = 1'b1;
    assign PREADY1 = 1'b1;
    assign PREADY2 = 1'b1;
    assign PREADY3 = 1'b1;

    //////////////////////////////////////////////////////////////////////////
    // Clock Generation
    //////////////////////////////////////////////////////////////////////////
    always #(CLK_PERIOD/2) PCLK = ~PCLK;

    //////////////////////////////////////////////////////////////////////////
    // Test Variables
    //////////////////////////////////////////////////////////////////////////
    logic [7:0] test_patterns [0:7];
    integer test_count;
    integer error_count;

    //////////////////////////////////////////////////////////////////////////
    // Main Test Sequence
    //////////////////////////////////////////////////////////////////////////
    initial begin
        // Initialize signals
        PCLK = 0;
        PRESET = 1;
        transfer = 0;
        write = 0;
        addr = 0;
        wdata = 0;
        tx_test_data = 8'h00;
        tx_start = 0;
        test_count = 0;
        error_count = 0;

        // Initialize test patterns
        test_patterns[0] = 8'h55;  // Alternating pattern
        test_patterns[1] = 8'hAA;  // Inverse alternating
        test_patterns[2] = 8'h00;  // All zeros
        test_patterns[3] = 8'hFF;  // All ones
        test_patterns[4] = 8'h5A;  // Mixed pattern
        test_patterns[5] = 8'h41;  // ASCII 'A'
        test_patterns[6] = 8'h48;  // ASCII 'H'
        test_patterns[7] = 8'h21;  // ASCII '!'

        $display("================================================================================");
        $display("Starting UART_Periph Comprehensive Verification");
        $display("Testing both UART loopback and APB read functionality");
        $display("================================================================================");

        // Reset sequence
        #(CLK_PERIOD * 10);
        PRESET = 0;
        #(CLK_PERIOD * 10);

        // Wait for system stabilization
        repeat(50) @(posedge PCLK);

        // Enable UART via APB write
        $display("\n[%0t] Enabling UART via APB Control Register...", $time);
        apb_write_task(CTRL_REG_ADDR, 32'h00000001);

        // Wait for UART to be enabled
        repeat(10) @(posedge PCLK);

        // Run verification tests for each pattern (reduced to 3 for clearer analysis)
        for (int i = 0; i < 3; i++) begin
            $display("\n================================================================================");
            $display("[%0t] Running Test %0d with pattern 0x%02X", $time, i+1, test_patterns[i]);
            $display("================================================================================");
            
            run_uart_test(test_patterns[i], i+1);
            
            // Wait longer between tests for clearer waveform analysis
            repeat(200) @(posedge PCLK);
        end

        // Final results
        $display("\n================================================================================");
        $display("VERIFICATION COMPLETE");
        $display("Total Tests: %0d", test_count);
        $display("Errors: %0d", error_count);
        if (error_count == 0) begin
            $display("STATUS: ALL TESTS PASSED!");
        end else begin
            $display("STATUS: %0d TESTS FAILED!", error_count);
        end
        $display("================================================================================");

        #(CLK_PERIOD * 100);
        $finish;
    end

    //////////////////////////////////////////////////////////////////////////
    // Test Tasks
    //////////////////////////////////////////////////////////////////////////

    // Main test task for each data pattern
    task run_uart_test(input logic [7:0] test_data, input integer test_num);
        logic [31:0] read_data;
        logic [7:0] received_loopback;
        logic [7:0] test_data_variant1, test_data_variant2, test_data_variant3;
        logic [7:0] unique_pattern;
        logic test_passed;
        
        test_count++;
        test_passed = 1'b1;
        
        // Create clearly different variants for each scenario
        test_data_variant1 = test_data;                    // Original data
        test_data_variant2 = test_data ^ 8'h0F;           // XOR with 0x0F 
        test_data_variant3 = test_data + 8'h10;           // Add 0x10
        unique_pattern = test_data + test_num + 8'h20;    // Add test_num + 0x20
        
        $display("\n--- Test %0d: Base=0x%02X, Var1=0x%02X, Var2=0x%02X, Var3=0x%02X, Unique=0x%02X ---", 
                 test_num, test_data, test_data_variant1, test_data_variant2, test_data_variant3, unique_pattern);
        
        // Scenario 1: External UART Loopback Test
        $display("[%0t] Scenario 1: External UART Loopback with 0x%02X", $time, test_data_variant1);
        uart_send_byte(test_data_variant1);
        wait_for_uart_reception();
        received_loopback = rx_received_data;
        
        if (received_loopback == test_data_variant1) begin
            $display("[%0t] ✓ External UART Loopback PASSED: 0x%02X -> 0x%02X", 
                     $time, test_data_variant1, received_loopback);
        end else begin
            $display("[%0t] ✗ External UART Loopback FAILED: 0x%02X -> 0x%02X", 
                     $time, test_data_variant1, received_loopback);
            test_passed = 1'b0;
            error_count++;
        end
        
        // Wait between scenarios
        repeat(300) @(posedge PCLK);
        
        // Scenario 2: UART RX -> APB Read Test
        $display("[%0t] Scenario 2: UART RX -> APB Read with 0x%02X", $time, test_data_variant2);
        uart_send_byte(test_data_variant2);
        
        // Wait for UART reception to complete
        repeat(600) @(posedge PCLK);
        
        // Read RX Register via APB
        apb_read_task(RX_REG_ADDR, read_data);
        $display("[%0t]   RX Register: 0x%08X", $time, read_data);
        
        if (read_data[7:0] == test_data_variant2) begin
            $display("[%0t] ✓ APB RX Read PASSED: 0x%02X -> 0x%02X", 
                     $time, test_data_variant2, read_data[7:0]);
        end else begin
            $display("[%0t] ✗ APB RX Read FAILED: 0x%02X -> 0x%02X", 
                     $time, test_data_variant2, read_data[7:0]);
            test_passed = 1'b0;
            error_count++;
        end
        
        // Wait between scenarios
        repeat(200) @(posedge PCLK);
        
        // Scenario 3: APB Write -> UART TX Test
        $display("[%0t] Scenario 3: APB Write -> UART TX with 0x%02X", $time, test_data_variant3);
        apb_write_task(TX_REG_ADDR, {24'h0, test_data_variant3});
        
        // Wait for DUT transmission and external reception
        wait_for_uart_reception();
        received_loopback = rx_received_data;
        
        if (received_loopback == test_data_variant3) begin
            $display("[%0t] ✓ APB TX Control PASSED: 0x%02X -> 0x%02X", 
                     $time, test_data_variant3, received_loopback);
        end else begin
            $display("[%0t] ✗ APB TX Control FAILED: 0x%02X -> 0x%02X", 
                     $time, test_data_variant3, received_loopback);
            test_passed = 1'b0;
            error_count++;
        end
        
        // Wait between scenarios
        repeat(200) @(posedge PCLK);
        
        // Scenario 4: Additional APB Tests with unique pattern
        $display("[%0t] Scenario 4: Additional APB Tests with 0x%02X", $time, unique_pattern);
        
        // Read some registers for variety
        apb_read_task(CTRL_REG_ADDR, read_data);
        apb_read_task(STATUS_REG_ADDR, read_data);
        
        // Write unique pattern to TX
        apb_write_task(TX_REG_ADDR, {24'h0, unique_pattern});
        $display("[%0t]   Unique pattern 0x%02X written to TX", $time, unique_pattern);
        
        // Final status check
        apb_read_task(STATUS_REG_ADDR, read_data);
        
        // Overall test result
        if (test_passed) begin
            $display("[%0t] ✓ Test %0d OVERALL: PASSED", $time, test_num);
        end else begin
            $display("[%0t] ✗ Test %0d OVERALL: FAILED", $time, test_num);
        end
        
    endtask

    // APB Write Task
    task apb_write_task(input logic [31:0] addr_in, input logic [31:0] wdata_in);
        begin
            @(posedge PCLK);
            // Start APB transaction
            transfer = 1'b1;
            write = 1'b1;
            addr = addr_in;
            wdata = wdata_in;
            
            // Wait for transaction completion
            @(posedge PCLK);
            wait(ready == 1'b1);
            
            @(posedge PCLK);
            // End transaction
            transfer = 1'b0;
            write = 1'b0;
            
            $display("[%0t] APB Write: Addr=0x%08X, Data=0x%08X", $time, addr_in, wdata_in);
            @(posedge PCLK);
        end
    endtask

    // APB Read Task
    task apb_read_task(input logic [31:0] addr_in, output logic [31:0] rdata_out);
        begin
            @(posedge PCLK);
            // Start APB transaction
            transfer = 1'b1;
            write = 1'b0;
            addr = addr_in;
            
            // Wait for transaction completion
            @(posedge PCLK);
            wait(ready == 1'b1);
            rdata_out = rdata;
            
            @(posedge PCLK);
            // End transaction
            transfer = 1'b0;
            write = 1'b0;
            
            $display("[%0t] APB Read: Addr=0x%08X, Data=0x%08X", $time, addr_in, rdata_out);
            @(posedge PCLK);
        end
    endtask

    // UART Send Byte Task
    task uart_send_byte(input logic [7:0] data);
        begin
            $display("[%0t] Initiating UART transmission of 0x%02X", $time, data);
            
            // Wait for uart_sender to be ready
            wait(tx_busy == 1'b0);
            
            @(posedge PCLK);
            tx_test_data = data;
            tx_start = 1'b1;
            
            @(posedge PCLK);
            tx_start = 1'b0;
            
            // Wait for transmission to start
            wait(tx_busy == 1'b1);
            $display("[%0t] UART transmission started", $time);
            
            // Wait for transmission to complete
            wait(tx_busy == 1'b0);
            $display("[%0t] UART transmission completed", $time);
        end
    endtask

    // Wait for UART Reception Task
    task wait_for_uart_reception();
        begin
            $display("[%0t] Waiting for UART reception...", $time);
            
            // Wait for reception to start
            wait(rx_busy == 1'b1);
            $display("[%0t] UART reception in progress", $time);
            
            // Wait for reception to complete
            wait(rx_done == 1'b1);
            $display("[%0t] UART reception completed", $time);
            
            // Allow one clock for data to settle
            @(posedge PCLK);
        end
    endtask

    //////////////////////////////////////////////////////////////////////////
    // Monitoring and Debugging
    //////////////////////////////////////////////////////////////////////////
    
    // Monitor UART traffic
    always @(posedge PCLK) begin
        if (tx_start) begin
            $display("[%0t] MONITOR: External UART Send initiated - Data: 0x%02X", $time, tx_test_data);
        end
        if (rx_done) begin
            $display("[%0t] MONITOR: External UART Receive completed - Data: 0x%02X", $time, rx_received_data);
        end
        
        // Monitor DUT internal UART signals
        if (dut_uart_tx_start) begin
            $display("[%0t] MONITOR: DUT UART TX started - Data: 0x%02X", $time, dut_uart_tx_data);
        end
        if (dut_uart_rx_done) begin
            $display("[%0t] MONITOR: DUT UART RX completed - Data: 0x%02X", $time, dut_uart_rx_data);
        end
    end

    // Monitor APB transactions
    always @(posedge PCLK) begin
        if (PSEL4 && PENABLE && PREADY4) begin
            if (PWRITE) begin
                $display("[%0t] MONITOR: APB Write to UART - Addr: 0x%08X, Data: 0x%08X", 
                         $time, PADDR, PWDATA);
                case (PADDR[7:0])
                    8'h00: $display("                   -> CTRL Register: Enable=%0d", PWDATA[0]);
                    8'h08: $display("                   -> TX Register: Data=0x%02X", PWDATA[7:0]);
                    default: $display("                   -> Unknown Register");
                endcase
            end else begin
                $display("[%0t] MONITOR: APB Read from UART - Addr: 0x%08X, Data: 0x%08X", 
                         $time, PADDR, PRDATA4);
                case (PADDR[7:0])
                    8'h04: $display("                   -> STATUS Register: 0x%08X", PRDATA4);
                    8'h0C: $display("                   -> RX Register: Data=0x%02X", PRDATA4[7:0]);
                    default: $display("                   -> Unknown Register");
                endcase
            end
        end
        
        // Debug: Monitor PRDATA4 changes
        if ($changed(PRDATA4)) begin
            $display("[%0t] DEBUG: PRDATA4 changed to 0x%08X", $time, PRDATA4);
        end
        
        // Debug: Monitor DUT internal RX data changes
        if ($changed(dut_uart_rx_data)) begin
            $display("[%0t] DEBUG: DUT RX data changed to 0x%02X", $time, dut_uart_rx_data);
        end
        
        // Debug: Monitor when APB tries to read but gets no response
        if (PSEL4 && PENABLE && !PREADY4) begin
            $display("[%0t] DEBUG: APB read pending - PREADY4 not asserted", $time);
        end
    end
    
    // Monitor signal transitions for debugging
    always @(posedge PCLK) begin
        // UART RX/TX line monitoring
        if ($changed(uart_rx_to_dut) || $changed(uart_tx_from_dut)) begin
            $display("[%0t] UART_LINES: RX=%0b, TX=%0b", $time, uart_rx_to_dut, uart_tx_from_dut);
        end
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 2000000);  // 20ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Supporting Modules
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////
// APB_UART: Container for uart_sender and uart_receiver
//////////////////////////////////////////////////////////////////////////
module APB_UART (
    input  logic       clk,
    input  logic       reset,
    // UART connections to DUT
    output logic       uart_tx_to_dut,      // Our TX -> DUT RX
    input  logic       uart_rx_from_dut,    // DUT TX -> Our RX
    // Control interface
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    output logic       tx_busy,
    output logic [7:0] rx_data,
    output logic       rx_done,
    output logic       rx_busy
);

    uart_sender sender_inst (
        .clk     (clk),
        .reset   (reset),
        .tx_data (tx_data),
        .tx_start(tx_start),
        .tx_busy (tx_busy),
        .uart_tx (uart_tx_to_dut)
    );

    uart_receiver receiver_inst (
        .clk     (clk),
        .reset   (reset),
        .uart_rx (uart_rx_from_dut),
        .rx_data (rx_data),
        .rx_done (rx_done),
        .rx_busy (rx_busy)
    );

endmodule

//////////////////////////////////////////////////////////////////////////
// uart_sender: Converts 8-bit parallel data to 1-bit serial UART data
//////////////////////////////////////////////////////////////////////////
module uart_sender (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    output logic       tx_busy,
    output logic       uart_tx
);

    // UART timing parameters (matching UART.sv)
    parameter BAUD_COUNT = 100_000_000 / (9600 * 16);  // Same as in baud_tick_gen
    
    // State definition
    typedef enum logic [2:0] {
        IDLE    = 3'b000,
        START   = 3'b001,
        DATA    = 3'b010,
        STOP    = 3'b011
    } state_t;
    
    state_t state, next_state;
    
    // Registers
    logic [7:0]  data_reg, data_next;
    logic [2:0]  bit_count, bit_count_next;
    logic [15:0] baud_tick_count, baud_tick_count_next;
    logic        baud_tick;
    logic        tx_reg, tx_next;
    logic        busy_reg, busy_next;
    
    // Baud tick generation (16x oversampling like in UART.sv)
    logic [$clog2(BAUD_COUNT)-1:0] tick_counter;
    logic tick_gen_reset;
    
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            tick_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (tick_counter == BAUD_COUNT - 1) begin
                tick_counter <= 0;
                baud_tick <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                baud_tick <= 0;
            end
        end
    end
    
    // Sequential logic
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            data_reg <= 8'h0;
            bit_count <= 3'h0;
            baud_tick_count <= 16'h0;
            tx_reg <= 1'b1;  // Idle high
            busy_reg <= 1'b0;
        end else begin
            state <= next_state;
            data_reg <= data_next;
            bit_count <= bit_count_next;
            baud_tick_count <= baud_tick_count_next;
            tx_reg <= tx_next;
            busy_reg <= busy_next;
        end
    end
    
    // Combinational logic
    always_comb begin
        // Default assignments
        next_state = state;
        data_next = data_reg;
        bit_count_next = bit_count;
        baud_tick_count_next = baud_tick_count;
        tx_next = tx_reg;
        busy_next = busy_reg;
        
        case (state)
            IDLE: begin
                tx_next = 1'b1;
                busy_next = 1'b0;
                baud_tick_count_next = 16'h0;
                if (tx_start) begin
                    next_state = START;
                    data_next = tx_data;
                    busy_next = 1'b1;
                    bit_count_next = 3'h0;
                end
            end
            
            START: begin
                tx_next = 1'b0;  // Start bit
                if (baud_tick) begin
                    if (baud_tick_count == 15) begin
                        next_state = DATA;
                        baud_tick_count_next = 16'h0;
                    end else begin
                        baud_tick_count_next = baud_tick_count + 1;
                    end
                end
            end
            
            DATA: begin
                tx_next = data_reg[0];  // LSB first
                if (baud_tick) begin
                    if (baud_tick_count == 15) begin
                        data_next = data_reg >> 1;
                        baud_tick_count_next = 16'h0;
                        if (bit_count == 7) begin
                            next_state = STOP;
                            bit_count_next = 3'h0;
                        end else begin
                            bit_count_next = bit_count + 1;
                        end
                    end else begin
                        baud_tick_count_next = baud_tick_count + 1;
                    end
                end
            end
            
            STOP: begin
                tx_next = 1'b1;  // Stop bit
                if (baud_tick) begin
                    if (baud_tick_count == 15) begin
                        next_state = IDLE;
                        baud_tick_count_next = 16'h0;
                        busy_next = 1'b0;
                    end else begin
                        baud_tick_count_next = baud_tick_count + 1;
                    end
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output assignments
    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    
endmodule

//////////////////////////////////////////////////////////////////////////
// uart_receiver: Converts 1-bit serial UART data to 8-bit parallel data
//////////////////////////////////////////////////////////////////////////
module uart_receiver (
    input  logic       clk,
    input  logic       reset,
    input  logic       uart_rx,
    output logic [7:0] rx_data,
    output logic       rx_done,
    output logic       rx_busy
);

    // UART timing parameters (matching UART.sv)
    parameter BAUD_COUNT = 100_000_000 / (9600 * 16);
    
    // State definition
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;
    
    state_t state, next_state;
    
    // Registers
    logic [7:0]  data_reg, data_next;
    logic [2:0]  bit_count, bit_count_next;
    logic [15:0] baud_tick_count, baud_tick_count_next;
    logic        baud_tick;
    logic        done_reg, done_next;
    logic        busy_reg, busy_next;
    
    // Baud tick generation
    logic [$clog2(BAUD_COUNT)-1:0] tick_counter;
    
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            tick_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (tick_counter == BAUD_COUNT - 1) begin
                tick_counter <= 0;
                baud_tick <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                baud_tick <= 0;
            end
        end
    end
    
    // Sequential logic
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            data_reg <= 8'h0;
            bit_count <= 3'h0;
            baud_tick_count <= 16'h0;
            done_reg <= 1'b0;
            busy_reg <= 1'b0;
        end else begin
            state <= next_state;
            data_reg <= data_next;
            bit_count <= bit_count_next;
            baud_tick_count <= baud_tick_count_next;
            done_reg <= done_next;
            busy_reg <= busy_next;
        end
    end
    
    // Combinational logic
    always_comb begin
        // Default assignments
        next_state = state;
        data_next = data_reg;
        bit_count_next = bit_count;
        baud_tick_count_next = baud_tick_count;
        done_next = 1'b0;  // done is pulse signal
        busy_next = busy_reg;
        
        case (state)
            IDLE: begin
                busy_next = 1'b0;
                if (~uart_rx) begin  // Start bit detected
                    next_state = START;
                    baud_tick_count_next = 16'h0;
                    bit_count_next = 3'h0;
                    busy_next = 1'b1;
                end
            end
            
            START: begin
                if (baud_tick) begin
                    if (baud_tick_count == 7) begin  // Sample at middle of start bit
                        next_state = DATA;
                        baud_tick_count_next = 16'h0;
                    end else begin
                        baud_tick_count_next = baud_tick_count + 1;
                    end
                end
            end
            
            DATA: begin
                if (baud_tick) begin
                    if (baud_tick_count == 15) begin  // Sample at middle of data bit
                        data_next = {uart_rx, data_reg[7:1]};  // MSB first reception
                        baud_tick_count_next = 16'h0;
                        if (bit_count == 7) begin
                            next_state = STOP;
                            bit_count_next = 3'h0;
                        end else begin
                            bit_count_next = bit_count + 1;
                        end
                    end else begin
                        baud_tick_count_next = baud_tick_count + 1;
                    end
                end
            end
            
            STOP: begin
                if (baud_tick) begin
                    if (baud_tick_count == 15) begin  // Sample at middle of stop bit
                        next_state = IDLE;
                        done_next = 1'b1;
                        busy_next = 1'b0;
                    end else begin
                        baud_tick_count_next = baud_tick_count + 1;
                    end
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output assignments
    assign rx_data = data_reg;
    assign rx_done = done_reg;
    assign rx_busy = busy_reg;
    
endmodule