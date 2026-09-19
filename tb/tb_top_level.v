`timescale 1ns / 1ps

module tb_top_level;

    // CLOCK PARAMETERS

    localparam integer CLK_PERIOD_NS = 100;       // 10 MHz
    localparam integer UART_BIT_NS   = 104167;    // 9600 baud approx.

    // TESTBENCH SIGNALS

    reg clk;
    reg reset;

    reg [7:0] battery_voltage_in;
    reg [9:0] rail_5v_in;
    reg [9:0] payload_current_in;
    reg [7:0] fpga_temperature_in;

    reg comm_status_in;
    reg payload_status_in;

    reg obc_heartbeat;

    reg uart_rx;
    wire uart_tx;

    reg tx_start;

    wire payload_enable;
    wire safe_mode;

    wire [7:0] fault_status;
    wire temp_warning;

    // DUT
    

    top_level uut (
        .clk                   (clk),
        .reset                 (reset),

        .battery_voltage_in    (battery_voltage_in),
        .rail_5v_in            (rail_5v_in),
        .payload_current_in    (payload_current_in),
        .fpga_temperature_in   (fpga_temperature_in),

        .comm_status_in        (comm_status_in),
        .payload_status_in     (payload_status_in),

        .obc_heartbeat         (obc_heartbeat),

        .uart_rx               (uart_rx),
        .uart_tx               (uart_tx),

        .tx_start              (tx_start),

        .payload_enable        (payload_enable),
        .safe_mode             (safe_mode),

        .fault_status          (fault_status),
        .temp_warning          (temp_warning)
    );

    // CLOCK GENERATION

    initial begin
        clk = 1'b0;

        forever begin
            #(CLK_PERIOD_NS/2);
            clk = ~clk;
        end
    end

    // OBC HEARTBEAT GENERATOR
    //
    // The watchdog expects periodic rising edges.
    // During TEST 4 we stop this heartbeat intentionally.

    reg heartbeat_enable;

    initial begin
        obc_heartbeat = 1'b0;

        forever begin

            if (heartbeat_enable) begin

                obc_heartbeat = 1'b1;
                #(100);

                obc_heartbeat = 1'b0;
                #(400);

            end

            else begin

                obc_heartbeat = 1'b0;
                #(100);
            end

        end
    end

    // UART INITIALIZATION
  

    initial begin
        uart_rx = 1'b1;       // UART idle = HIGH
        tx_start = 1'b0;
    end

    // UART SEND BYTE TASK
    //
    // 8-N-1 UART
    // LSB first

    task uart_send_byte;
        input [7:0] data;
        integer i;

        begin

            // Start bit
            uart_rx = 1'b0;
            #(UART_BIT_NS);

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #(UART_BIT_NS);
            end

            // Stop bit
            uart_rx = 1'b1;
            #(UART_BIT_NS);

        end
    endtask

    // RESTORE NORMAL SENSOR CONDITIONS

    task normal_conditions;

        begin

            battery_voltage_in  = 8'd75;    // 7.5 V
            rail_5v_in           = 10'd500;  // 5.0 V
            payload_current_in   = 10'd150;  // 1.5 A
            fpga_temperature_in  = 8'd25;    // 25 C

            comm_status_in       = 1'b1;
            payload_status_in    = 1'b1;

        end

    endtask


    // CLEAR FAULT WITH HEARTBEAT ACTIVE
    //
    // 0xCC = FAULT_CLEAR
    //
    // Heartbeat must continue because watchdog timeout is only
    // 100 clock cycles, while a UART byte takes much longer.
  

    task clear_fault;

        begin

            heartbeat_enable = 1'b1;

            uart_send_byte(8'hCC);

            // Allow UART receiver and fault register
            // to process the command.
            repeat (20) @(posedge clk);

        end

    endtask


    initial begin

        // INITIAL VALUES

        reset = 1'b1;

        heartbeat_enable = 1'b1;

        normal_conditions();

        uart_rx = 1'b1;
        tx_start = 1'b0;

        // Hold reset
        repeat (5) @(posedge clk);

        reset = 1'b0;

        // Allow system to initialize
        repeat (20) @(posedge clk);


        // TEST 1 - NORMAL OPERATION

        $display("");
        $display("TEST 1: NORMAL OPERATION");

        normal_conditions();

        repeat (30) @(posedge clk);

        if ((fault_status == 8'b00000000) &&
            (payload_enable == 1'b1) &&
            (safe_mode == 1'b0)) begin

            $display("TEST 1 PASS: Normal operation");

        end
        else begin

            $display("TEST 1 FAIL");
            $display("fault_status = %b", fault_status);
            $display("payload_enable = %b", payload_enable);
            $display("safe_mode = %b", safe_mode);

        end


        // TEST 2 - PERSISTENT PAYLOAD OVER-CURRENT

        $display("");
        $display("TEST 2: PERSISTENT PAYLOAD OVER-CURRENT");

        normal_conditions();

        // 2.5 A > 2 A limit
        payload_current_in = 10'd250;

        // Persistence count = 10
        repeat (20) @(posedge clk);

        if ((fault_status[2] == 1'b1) &&
            (payload_enable == 1'b0)) begin

            $display("TEST 2 PASS: Payload over-current detected");

        end
        else begin

            $display("TEST 2 FAIL");
            $display("fault_status = %b", fault_status);
            $display("payload_enable = %b", payload_enable);

        end

        // Return current to normal
        payload_current_in = 10'd150;

        repeat (20) @(posedge clk);

        // Clear latched fault
        clear_fault();

        repeat (20) @(posedge clk);


        // TEST 3 - TRANSIENT CURRENT SPIKE

        $display("");
        $display("TEST 3: TRANSIENT CURRENT SPIKE");

        normal_conditions();

        // Short current spike
        payload_current_in = 10'd250;

        // Less than persistence requirement
        repeat (5) @(posedge clk);

        payload_current_in = 10'd150;

        repeat (20) @(posedge clk);

        if ((fault_status[2] == 1'b0) &&
            (payload_enable == 1'b1)) begin

            $display("TEST 3 PASS: Transient spike ignored");

        end
        else begin

            $display("TEST 3 FAIL");
            $display("fault_status = %b", fault_status);
            $display("payload_enable = %b", payload_enable);

        end


        // TEST 4 - OBC HEARTBEAT FAILURE

        $display("");
        $display("TEST 4: OBC HEARTBEAT FAILURE");

        normal_conditions();

        // Stop heartbeat
        heartbeat_enable = 1'b0;
        obc_heartbeat = 1'b0;

        // Watchdog timeout = 100 clock cycles
        repeat (150) @(posedge clk);

        if (fault_status[4] == 1'b1) begin

            $display("TEST 4 PASS: OBC watchdog timeout detected");

        end
        else begin

            $display("TEST 4 FAIL");
            $display("fault_status = %b", fault_status);

        end

        // Restore heartbeat
        heartbeat_enable = 1'b1;

        repeat (20) @(posedge clk);
      
        // TEST 5 - FPGA OVER-TEMPERATURE

        $display("");
        $display("TEST 5: FPGA OVER-TEMPERATURE");

        // Clear previous OBC fault
        normal_conditions();

        clear_fault();

        repeat (20) @(posedge clk);

        // 90 C > 85 C limit
        fpga_temperature_in = 8'd90;

        repeat (20) @(posedge clk);

        if (fault_status[3] == 1'b1) begin

            $display("TEST 5 PASS: Over-temperature detected");

        end
        else begin

            $display("TEST 5 FAIL");
            $display("fault_status = %b", fault_status);

        end

        // Return temperature to normal
        fpga_temperature_in = 8'd25;

        repeat (20) @(posedge clk);

        // Clear fault
        clear_fault();

        repeat (20) @(posedge clk);


        // TEST 6 - MULTIPLE FAULTS
        

        $display("");
        $display("TEST 6: MULTIPLE FAULTS");

        normal_conditions();

        // Create recoverable payload over-current
        payload_current_in = 10'd250;

        // Create critical battery under-voltage
        battery_voltage_in = 8'd65;    // < 7.0 V

        repeat (20) @(posedge clk);

        // Critical response should be selected
        if ((fault_status[0] == 1'b1) &&
            (fault_status[2] == 1'b1) &&
            (safe_mode == 1'b1)) begin

            $display("TEST 6 PASS: Critical response selected");

        end
        else begin

            $display("TEST 6 FAIL");
            $display("fault_status = %b", fault_status);
            $display("payload_enable = %b", payload_enable);
            $display("safe_mode = %b", safe_mode);

        end

        // Return all sensors to normal
        normal_conditions();

        repeat (20) @(posedge clk);


      
        // TEST 7 - FAULT CLEAR

        $display("");
        $display("TEST 7: FAULT CLEAR");

        // Make sure heartbeat is active
        heartbeat_enable = 1'b1;

        // Make sure all sensor conditions are normal
        normal_conditions();

        repeat (20) @(posedge clk);

        // Send explicit FAULT_CLEAR command
        uart_send_byte(8'hCC);

        // Allow UART receiver and fault register to process
        repeat (30) @(posedge clk);

        if (fault_status == 8'b00000000) begin

            $display("TEST 7 PASS: Fault register cleared");

        end
        else begin

            $display("TEST 7 FAIL");
            $display("fault_status = %b", fault_status);

        end


       
        // END OF ALL TESTS
      

        $display("");
     
        $display("ALL TESTS COMPLETED");
   
        #1000;

        $finish;

    end

endmodule
