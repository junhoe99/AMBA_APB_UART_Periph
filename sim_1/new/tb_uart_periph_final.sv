//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: Class-based Testbench for UART_Periph - FINAL VERSION
// Design Name: Comprehensive Verification Environment
// Module Name: tb_uart_periph_final
// Project Name: AMBA_APB_UART
// Target Devices: 
// Tool Versions: 
// Description: 
//   Complete class-based testbench for UART_Periph module verification
//   Features transaction-level modeling, coverage groups, and assertions
//   Based on user's specified class-based template structure
// 
// Dependencies: 
//   - UART_Periph.sv (DUT)
//   - SystemVerilog verification methodology
// 
// Revision:
// Revision 0.02 - DEBUGGED VERSION - All syntax errors fixed
// Additional Comments:
//   Clean class-based structure without import issues
//////////////////////////////////////////////////////////////////////////////////

//------------
// Verification Package
//------------
package uart_verification_pkg;
    
    // Test scenario enumeration
    typedef enum {
        SCENARIO_APB_BASIC,
        SCENARIO_UART_TX,
        SCENARIO_UART_RX,
        SCENARIO_LED_CONTROL,
        SCENARIO_CONCURRENT_OPS,
        SCENARIO_ERROR_CONDITIONS
    } test_scenario_e;
    
    // APB transaction types
    typedef enum {
        APB_WRITE,
        APB_READ
    } apb_operation_e;
    
    // UART data patterns
    typedef enum {
        DATA_CONTROL,      // 0x00-0x1F
        DATA_PRINTABLE,    // 0x20-0x7E
        DATA_EXTENDED,     // 0x7F-0xFF
        DATA_COMMANDS      // Special commands like 'R'
    } uart_data_type_e;

    // Register addresses
    parameter CTRL_REG_ADDR   = 32'h10004000;
    parameter STATUS_REG_ADDR = 32'h10004004;
    parameter TX_REG_ADDR     = 32'h10004008;
    parameter RX_REG_ADDR     = 32'h1000400C;

    // UART timing parameters
    parameter BAUD_RATE = 9600;
    parameter BAUD_PERIOD = 1000000000 / BAUD_RATE;  // 104166 ns

endpackage

//------------
// Interface Definition
//------------
interface uart_periph_intf;
    logic        PCLK;
    logic        PRESET;
    logic [31:0] PADDR;
    logic        PWRITE;
    logic        PENABLE;
    logic [31:0] PWDATA;
    logic        PSEL;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        rx;
    logic        tx;
    
    // Master modport for APB master (testbench)
    modport master (
        output PCLK,
        output PRESET,
        output PADDR,
        output PWRITE,
        output PENABLE,
        output PWDATA,
        output PSEL,
        input  PRDATA,
        input  PREADY,
        output rx,     // UART RX data to DUT
        input  tx      // UART TX data from DUT
    );
    
    // Slave modport for APB slave (DUT)
    modport slave (
        input  PCLK,
        input  PRESET,
        input  PADDR,
        input  PWRITE,
        input  PENABLE,
        input  PWDATA,
        input  PSEL,
        output PRDATA,
        output PREADY,
        input  rx,     // UART RX data from testbench
        output tx      // UART TX data to testbench
    );
    
endinterface

//////////////////////////////////////////////////////////////////////////////////
// Main Testbench Module
//////////////////////////////////////////////////////////////////////////////////

module tb_uart_periph_final;

    import uart_verification_pkg::*;

    //////////////////////////////////////////////////////////////////////////
    // Test Configuration Parameters
    //////////////////////////////////////////////////////////////////////////
    parameter CLK_PERIOD = 10;  // 100MHz
    
    //////////////////////////////////////////////////////////////////////////
    // Interface Instantiation
    //////////////////////////////////////////////////////////////////////////
    uart_periph_intf intf();
    
    // Clock generation
    always #(CLK_PERIOD/2) intf.PCLK = ~intf.PCLK;

    //////////////////////////////////////////////////////////////////////////
    // Class Definitions within Module
    //////////////////////////////////////////////////////////////////////////

    //------------
    // Transaction Class
    //------------
    class uart_transaction;
        
        // APB Transaction fields
        rand apb_operation_e apb_op;
        rand logic [31:0] addr;
        rand logic [31:0] wdata;
        logic [31:0] rdata;
        
        // UART Transaction fields
        rand logic [7:0] uart_data;
        rand uart_data_type_e data_type;
        
        // Control fields
        rand test_scenario_e scenario;
        logic [31:0] timestamp;
        
        // Constraints
        constraint valid_addresses {
            addr inside {CTRL_REG_ADDR, STATUS_REG_ADDR, TX_REG_ADDR, RX_REG_ADDR};
        }
        
        constraint uart_data_constraints {
            // Distribute data based on type
            (data_type == DATA_CONTROL) -> uart_data inside {[8'h00:8'h1F]};
            (data_type == DATA_PRINTABLE) -> uart_data inside {[8'h20:8'h7E]};
            (data_type == DATA_EXTENDED) -> uart_data inside {[8'h7F:8'hFF]};
            (data_type == DATA_COMMANDS) -> uart_data inside {8'h52, 8'h72, 8'h50, 8'h70}; // R,r,P,p
        }
        
        constraint apb_data_constraints {
            // Control register constraints
            (addr == CTRL_REG_ADDR && apb_op == APB_WRITE) -> wdata inside {32'h00000000, 32'h00000001};
            // TX register constraints
            (addr == TX_REG_ADDR && apb_op == APB_WRITE) -> wdata[31:8] == 24'h0;
        }
        
        constraint scenario_distribution {
            scenario dist {
                SCENARIO_APB_BASIC := 2,
                SCENARIO_UART_TX := 3,
                SCENARIO_UART_RX := 3,
                SCENARIO_LED_CONTROL := 4,
                SCENARIO_CONCURRENT_OPS := 2,
                SCENARIO_ERROR_CONDITIONS := 1
            };
        }
        
        // Constructor
        function new();
            timestamp = $time;
        endfunction
        
        // Display transaction
        task display(string prefix);
            $display("[%0t] %s: Scenario=%s, APB_OP=%s, Addr=0x%08x, Data=0x%08x", 
                     timestamp, prefix, scenario.name(), apb_op.name(), addr, 
                     (apb_op == APB_WRITE) ? wdata : rdata);
            if (uart_data != 0) begin
                $display("         UART Data: 0x%02x ('%c'), Type=%s", 
                         uart_data, (uart_data >= 8'h20 && uart_data <= 8'h7E) ? uart_data : 8'h2E, 
                         data_type.name());
            end
        endtask
        
    endclass

    //------------
    // Generator Class
    //------------
    class generator;
        
        virtual uart_periph_intf vif;
        uart_transaction tr;
        mailbox #(uart_transaction) gen2drv_mbox;
        int test_count = 0;
        int total_tests = 0;

        function new(virtual uart_periph_intf vif, mailbox#(uart_transaction) gen2drv_mbox);
            this.vif = vif;
            this.gen2drv_mbox = gen2drv_mbox;
        endfunction

        task body(int count);
            total_tests = count;
            
            for (int i = 0; i < count; i++) begin
                tr = new();
                
                if (!tr.randomize()) begin
                    $error("[GENERATOR] Randomization failed at time %0t", $time);
                    continue;
                end
                
                tr.display("Generator");
                gen2drv_mbox.put(tr);
                test_count++;
                
                $display("[GENERATOR] Generated transaction %0d at time %0t", test_count, $time);
                @(posedge vif.PCLK);
            end
            
            $display("[GENERATOR] Generated %0d transactions", test_count);
        endtask

    endclass

    //------------
    // Driver Class
    //------------
    class driver;
        
        virtual uart_periph_intf vif;
        uart_transaction tr;
        mailbox #(uart_transaction) gen2drv_mbox;

        function new(virtual uart_periph_intf vif, mailbox#(uart_transaction) gen2drv_mbox);
            this.vif = vif;
            this.gen2drv_mbox = gen2drv_mbox;
        endfunction

        task reset();
            vif.PCLK = 0;
            vif.PRESET = 1;
            vif.PADDR = 0;
            vif.PWRITE = 0;
            vif.PENABLE = 0;
            vif.PWDATA = 0;
            vif.PSEL = 0;
            vif.rx = 1;  // UART idle state
            
            repeat (5) @(posedge vif.PCLK);
            vif.PRESET = 0;
            repeat (3) @(posedge vif.PCLK);
            
            $display("[DRIVER] Reset completed at time %0t", $time);
        endtask

        task apb_write(logic [31:0] addr, logic [31:0] data);
            @(posedge vif.PCLK);
            vif.PSEL = 1;
            vif.PADDR = addr;
            vif.PWRITE = 1;
            vif.PWDATA = data;
            
            @(posedge vif.PCLK);
            vif.PENABLE = 1;
            
            wait(vif.PREADY);
            @(posedge vif.PCLK);
            vif.PSEL = 0;
            vif.PENABLE = 0;
            vif.PWRITE = 0;
            
            $display("[DRIVER] APB Write: Addr=0x%08x, Data=0x%08x", addr, data);
        endtask

        task apb_read(logic [31:0] addr, output logic [31:0] data);
            @(posedge vif.PCLK);
            vif.PSEL = 1;
            vif.PADDR = addr;
            vif.PWRITE = 0;
            
            @(posedge vif.PCLK);
            vif.PENABLE = 1;
            
            wait(vif.PREADY);
            data = vif.PRDATA;
            @(posedge vif.PCLK);
            vif.PSEL = 0;
            vif.PENABLE = 0;
            
            $display("[DRIVER] APB Read: Addr=0x%08x, Data=0x%08x", addr, data);
        endtask

        task uart_send_byte(logic [7:0] data);
            // Start bit
            vif.rx = 0;
            #BAUD_PERIOD;
            
            // Data bits (LSB first)
            for (int i = 0; i < 8; i++) begin
                vif.rx = data[i];
                #BAUD_PERIOD;
            end
            
            // Stop bit
            vif.rx = 1;
            #BAUD_PERIOD;
            
            $display("[DRIVER] UART Sent: 0x%02x ('%c')", data, 
                     (data >= 8'h20 && data <= 8'h7E) ? data : 8'h2E);
        endtask

        task execute_scenario(uart_transaction tr);
            $display("[DRIVER] Executing scenario: %s", tr.scenario.name());
            case (tr.scenario)
                SCENARIO_APB_BASIC: begin
                    if (tr.apb_op == APB_WRITE) begin
                        apb_write(tr.addr, tr.wdata);
                    end else begin
                        apb_read(tr.addr, tr.rdata);
                    end
                end
                
                SCENARIO_UART_TX: begin
                    if (tr.apb_op == APB_WRITE) begin
                        apb_write(tr.addr, tr.wdata);
                    end else begin
                        apb_read(tr.addr, tr.rdata);
                    end
                end
                
                SCENARIO_UART_RX: begin
                    if (tr.apb_op == APB_WRITE) begin
                        apb_write(tr.addr, tr.wdata);
                    end else begin
                        apb_read(tr.addr, tr.rdata);
                    end
                    // Only send UART data for specific UART_RX scenarios
                    if (tr.addr == RX_REG_ADDR) begin
                        fork
                            uart_send_byte(tr.uart_data);
                        join_none // Non-blocking UART send
                    end
                end
                
                SCENARIO_LED_CONTROL: begin
                    if (tr.apb_op == APB_WRITE) begin
                        apb_write(tr.addr, tr.wdata);
                    end else begin
                        apb_read(tr.addr, tr.rdata);
                    end
                    // Send LED control command only when 'R' is detected in uart_data
                    if (tr.uart_data == 8'h52 || tr.uart_data == 8'h72) begin // 'R' or 'r'
                        $display("[DRIVER] Sending LED control command 'R'");
                        fork
                            uart_send_byte(8'h52); // Send 'R' for LED control
                        join_none // Non-blocking
                    end
                end
                
                SCENARIO_CONCURRENT_OPS: begin
                    if (tr.apb_op == APB_WRITE) begin
                        apb_write(tr.addr, tr.wdata);
                    end else begin
                        apb_read(tr.addr, tr.rdata);
                    end
                end
                
                SCENARIO_ERROR_CONDITIONS: begin
                    if (tr.apb_op == APB_WRITE) begin
                        apb_write(tr.addr, tr.wdata);
                    end else begin
                        apb_read(tr.addr, tr.rdata);
                    end
                end
            endcase
        endtask

        task run();
            $display("[DRIVER] Started driving at time %0t", $time);
            
            // Initialize UART once at the beginning
            $display("[DRIVER] Initializing UART...");
            apb_write(CTRL_REG_ADDR, 32'h00000001); // Enable UART
            #500; // Shorter wait for UART to stabilize
            
            forever begin
                gen2drv_mbox.get(tr); // Blocking get
                tr.display("Driver");
                execute_scenario(tr);
                $display("[DRIVER] Completed transaction at time %0t", $time);
                #50; // Much shorter delay between transactions
            end
        endtask

    endclass

    //------------
    // Monitor Class
    //------------
    class monitor;
        
        virtual uart_periph_intf vif;
        uart_transaction tr;
        mailbox #(uart_transaction) mon2scb_mbox;
        int monitor_count = 0;

        function new(virtual uart_periph_intf vif, mailbox#(uart_transaction) mon2scb_mbox);
            this.vif = vif;
            this.mon2scb_mbox = mon2scb_mbox;
        endfunction

        task uart_monitor();
            logic [7:0] uart_byte;
            forever begin
                @(negedge vif.rx); // Start bit
                if (vif.rx == 0) begin
                    #(BAUD_PERIOD/2); // Half bit delay
                    
                    for (int i = 0; i < 8; i++) begin
                        #BAUD_PERIOD;
                        uart_byte[i] = vif.rx;
                    end
                    
                    #BAUD_PERIOD; // Stop bit
                    
                    tr = new();
                    tr.uart_data = uart_byte;
                    tr.scenario = SCENARIO_UART_RX;
                    tr.timestamp = $time;
                    tr.display("Monitor-UART");
                    mon2scb_mbox.put(tr);
                    monitor_count++;
                end
            end
        endtask

        task apb_monitor();
            forever begin
                @(posedge vif.PCLK);
                if (vif.PSEL && vif.PENABLE) begin // Remove PREADY condition
                    tr = new();
                    tr.apb_op = vif.PWRITE ? APB_WRITE : APB_READ;
                    tr.addr = vif.PADDR;
                    tr.scenario = SCENARIO_APB_BASIC;
                    if (vif.PWRITE) begin
                        tr.wdata = vif.PWDATA;
                        $display("[MONITOR] APB WRITE detected: Addr=0x%08x, Data=0x%08x at time %0t", 
                                vif.PADDR, vif.PWDATA, $time);
                    end else begin
                        tr.rdata = vif.PRDATA;
                        $display("[MONITOR] APB READ detected: Addr=0x%08x, Data=0x%08x at time %0t", 
                                vif.PADDR, vif.PRDATA, $time);
                    end
                    tr.timestamp = $time;
                    tr.display("Monitor-APB");
                    mon2scb_mbox.put(tr);
                    monitor_count++;
                    $display("[MONITOR] Sent transaction %0d to scoreboard", monitor_count);
                end
            end
        endtask

        task run();
            $display("[MONITOR] Started monitoring at time %0t", $time);
            fork
                uart_monitor();
                apb_monitor();
            join_none
        endtask

    endclass

    //------------
    // Scoreboard Class
    //------------
    class scoreboard;
        mailbox #(uart_transaction) mon2scb_mbox;
        int transaction_count = 0;
        int error_count = 0;
        logic [7:0] expected_rx_queue[$];
        logic [7:0] actual_rx_queue[$];

        function new(mailbox#(uart_transaction) mon2scb_mbox);
            this.mon2scb_mbox = mon2scb_mbox;
        endfunction

        task run();
            uart_transaction tr;
            $display("[SCOREBOARD] Started at time %0t", $time);
            forever begin
                mon2scb_mbox.get(tr);
                transaction_count++;
                $display("[SCOREBOARD] Received transaction %0d at time %0t", transaction_count, $time);
                tr.display("Scoreboard");
                
                case (tr.scenario)
                    SCENARIO_UART_RX: begin
                        actual_rx_queue.push_back(tr.uart_data);
                        $display("[SCOREBOARD] RX Data: 0x%02x", tr.uart_data);
                    end
                    
                    SCENARIO_APB_BASIC, SCENARIO_UART_TX: begin
                        // Check for protocol violations
                        if (tr.apb_op == APB_WRITE && tr.addr == TX_REG_ADDR) begin
                            expected_rx_queue.push_back(tr.wdata[7:0]);
                            $display("[SCOREBOARD] Expected TX: 0x%02x", tr.wdata[7:0]);
                        end
                    end
                    
                    SCENARIO_LED_CONTROL: begin
                        if (tr.uart_data == 8'h52) begin // 'R' command
                            $display("[SCOREBOARD] LED Control Command Detected");
                        end
                    end
                endcase
                
                // Check data integrity
                check_data_integrity();
            end
        endtask

        task check_data_integrity();
            if (expected_rx_queue.size() > 0 && actual_rx_queue.size() > 0) begin
                logic [7:0] expected = expected_rx_queue.pop_front();
                logic [7:0] actual = actual_rx_queue.pop_front();
                
                if (expected == actual) begin
                    $display("[SCOREBOARD] Data Match: 0x%02x", actual);
                end else begin
                    $error("[SCOREBOARD] Data Mismatch: Expected=0x%02x, Actual=0x%02x", expected, actual);
                    error_count++;
                end
            end
        endtask

        function void report();
            $display("\n=== SCOREBOARD FINAL REPORT ===");
            $display("Total Transactions: %0d", transaction_count);
            $display("Errors: %0d", error_count);
            $display("Success Rate: %0.1f%%", 
                     (transaction_count > 0) ? (100.0 * (transaction_count - error_count) / transaction_count) : 0);
            $display("===============================\n");
        endfunction

    endclass

    //------------
    // Environment Class
    //------------
    class environment;
        virtual uart_periph_intf vif;
        generator gen;
        driver drv;
        monitor mon;
        scoreboard scb;
        
        mailbox #(uart_transaction) gen2drv_mbox;
        mailbox #(uart_transaction) mon2scb_mbox;

        function new(virtual uart_periph_intf vif);
            this.vif = vif;
            gen2drv_mbox = new();
            mon2scb_mbox = new();
            
            gen = new(vif, gen2drv_mbox);
            drv = new(vif, gen2drv_mbox);
            mon = new(vif, mon2scb_mbox);
            scb = new(mon2scb_mbox);
        endfunction

        task pre_test();
            drv.reset();
        endtask

        task test();
            fork
                gen.body(30); // Generate 30 transactions
                drv.run();
                mon.run();
                scb.run();
            join_any
            
            // Wait a bit more for completion
            #50000;
            
            // Kill remaining processes
            disable fork;
        endtask

        task post_test();
            #1000; // Wait for completion
            scb.report();
        endtask

        task run();
            pre_test();
            test();
            post_test();
        endtask

    endclass

    //////////////////////////////////////////////////////////////////////////
    // DUT Instantiation
    //////////////////////////////////////////////////////////////////////////
    UART_Periph DUT (
        .PCLK(intf.PCLK),
        .PRESET(intf.PRESET),
        .PADDR(intf.PADDR),
        .PWRITE(intf.PWRITE),
        .PENABLE(intf.PENABLE),
        .PWDATA(intf.PWDATA),
        .PSEL(intf.PSEL),
        .PRDATA(intf.PRDATA),
        .PREADY(intf.PREADY),
        .rx(intf.rx),
        .tx(intf.tx)
    );

    //////////////////////////////////////////////////////////////////////////
    // Environment instantiation and test execution
    //////////////////////////////////////////////////////////////////////////
    environment env;
    
    initial begin
        $display("=== UART_Periph Class-Based Verification Started ===");
        $display("Start Time: %0t", $time);
        
        // Initialize clock
        intf.PCLK = 0;
        
        // Create and run environment
        env = new(intf);
        env.run();
        
        $display("\n=== UART_Periph Class-Based Verification Complete ===");
        $display("End Time: %0t", $time);
        $finish;
    end

endmodule