module sensor_interface (
    input  wire [7:0]  battery_voltage_in,
    input  wire [9:0]  rail_5v_in,
    input  wire [9:0]  payload_current_in,
    input  wire [7:0]  fpga_temperature_in,
    input  wire        comm_status_in,
    input  wire        payload_status_in,

    output wire [7:0]  battery_voltage,
    output wire [9:0]  rail_5v,
    output wire [9:0]  payload_current,
    output wire [7:0]  fpga_temperature,
    output wire        comm_status,
    output wire        payload_status
);

    // Pass simulated sensor values to the FDIR system

    assign battery_voltage  = battery_voltage_in;
    assign rail_5v          = rail_5v_in;
    assign payload_current  = payload_current_in;
    assign fpga_temperature = fpga_temperature_in;
    assign comm_status      = comm_status_in;
    assign payload_status   = payload_status_in;

endmodule
