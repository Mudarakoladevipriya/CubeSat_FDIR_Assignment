module top_level (
    input  wire        clk,
    input  wire        reset,

    // Simulated sensor / health inputs
    input  wire [7:0]  battery_voltage_in,
    input  wire [9:0]  rail_5v_in,
    input  wire [9:0]  payload_current_in,
    input  wire [7:0]  fpga_temperature_in,
    input  wire        comm_status_in,
    input  wire        payload_status_in,

    // OBC heartbeat
    input  wire        obc_heartbeat,

    // UART
    input  wire        uart_rx,
    output wire        uart_tx,

    // UART transmit request
    input  wire        tx_start,

    // Protection outputs
    output wire        payload_enable,
    output wire        safe_mode,

    // Fault register output
    output wire [7:0]  fault_status,

    // Temperature warning
    output wire        temp_warning
);

   
    // Sensor interface outputs
   

    wire [7:0] battery_voltage;
    wire [9:0] rail_5v;
    wire [9:0] payload_current;
    wire [7:0] fpga_temperature;
    wire       comm_status;
    wire       payload_status;


    // Fault detector outputs


    wire battery_uv_fault;
    wire battery_ov_fault;
    wire rail_5v_fault;
    wire payload_oc_fault;
    wire fpga_ot_fault;
    wire comm_timeout_fault;
    wire payload_failure_fault;

  
    // Watchdog
   

    wire obc_timeout;

    
    // Fault manager
 

    wire       fault_detected;
    wire [1:0] fault_severity;

  
    // UART signals
   

    wire       rx_valid;
    wire [7:0] rx_data;
    wire       fault_clear;
    wire       tx_busy;


    // 1. SENSOR INTERFACE


    sensor_interface u_sensor_interface (
        .battery_voltage_in  (battery_voltage_in),
        .rail_5v_in          (rail_5v_in),
        .payload_current_in  (payload_current_in),
        .fpga_temperature_in (fpga_temperature_in),
        .comm_status_in      (comm_status_in),
        .payload_status_in   (payload_status_in),

        .battery_voltage     (battery_voltage),
        .rail_5v             (rail_5v),
        .payload_current     (payload_current),
        .fpga_temperature    (fpga_temperature),
        .comm_status         (comm_status),
        .payload_status      (payload_status)
    );

   
    // 2. FAULT DETECTOR
 

    fault_detector #(
        .PERSISTENCE_COUNT(10)
    ) u_fault_detector (
        .clk                   (clk),
        .reset                 (reset),

        .battery_voltage       (battery_voltage),
        .rail_5v               (rail_5v),
        .payload_current       (payload_current),
        .fpga_temperature      (fpga_temperature),
        .comm_status           (comm_status),
        .payload_status        (payload_status),

        .battery_uv_fault      (battery_uv_fault),
        .battery_ov_fault      (battery_ov_fault),
        .rail_5v_fault         (rail_5v_fault),
        .payload_oc_fault      (payload_oc_fault),
        .fpga_ot_fault         (fpga_ot_fault),
        .comm_timeout_fault    (comm_timeout_fault),
        .payload_failure_fault (payload_failure_fault),
        .temp_warning          (temp_warning)
    );


    // 3. OBC WATCHDOG


    watchdog #(
        .TIMEOUT_COUNT(100)
    ) u_watchdog (
        .clk           (clk),
        .reset         (reset),
        .obc_heartbeat (obc_heartbeat),
        .obc_timeout   (obc_timeout)
    );

  fault_manager u_fault_manager (
    .battery_uv_fault       (battery_uv_fault),
    .battery_ov_fault       (battery_ov_fault),
    .rail_5v_fault          (rail_5v_fault),
    .payload_oc_fault       (payload_oc_fault),
    .fpga_ot_fault          (fpga_ot_fault),
    .obc_timeout            (obc_timeout),
    .comm_timeout_fault     (comm_timeout_fault),
    .payload_failure_fault  (payload_failure_fault),
    .temp_warning           (temp_warning),

    .fault_detected         (fault_detected),
    .fault_severity         (fault_severity)
);
  

  
    // 5. FAULT REGISTER
  
    fault_register u_fault_register (
        .clk         (clk),
        .reset       (reset),

        .fault_events({
            1'b0,                   // bit 7 - reserved
            payload_failure_fault,  // bit 6
            comm_timeout_fault,     // bit 5
            obc_timeout,            // bit 4
            fpga_ot_fault,          // bit 3
            payload_oc_fault,       // bit 2
            battery_ov_fault,       // bit 1
            battery_uv_fault        // bit 0
        }),

        .fault_clear  (fault_clear),
        .fault_status (fault_status)
    );
  
    // 6. PROTECTION FSM

    protection_fsm u_protection_fsm (
        .clk            (clk),
        .reset          (reset),

        .fault_detected (fault_detected),
        .fault_severity (fault_severity),
        .fault_clear    (fault_clear),

        .payload_enable (payload_enable),
        .safe_mode      (safe_mode)
    );

   
    // 7. UART INTERFACE

    uart_interface #(
        .CLK_FREQ        (10_000_000),
        .BAUD_RATE       (9600),
        .FAULT_CLEAR_CMD (8'hCC)
    ) u_uart (
        .clk          (clk),
        .reset        (reset),

        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx),

        .fault_status (fault_status),

        .tx_start     (tx_start),
        .tx_busy      (tx_busy),

        .rx_valid     (rx_valid),
        .rx_data      (rx_data),

        .fault_clear  (fault_clear)
    );

endmodule
