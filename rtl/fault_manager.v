module fault_manager (
    input  wire battery_uv_fault,
    input  wire battery_ov_fault,
    input  wire rail_5v_fault,
    input  wire payload_oc_fault,
    input  wire fpga_ot_fault,
    input  wire obc_timeout,
    input  wire comm_timeout_fault,
    input  wire payload_failure_fault,
    input  wire temp_warning,

    output reg       fault_detected,
    output reg [1:0] fault_severity
);

    // Severity levels
    localparam SEV_NONE        = 2'b00;
    localparam SEV_WARNING     = 2'b01;
    localparam SEV_RECOVERABLE = 2'b10;
    localparam SEV_CRITICAL    = 2'b11;

    always @(*) begin

        // Default
        fault_detected = 1'b0;
        fault_severity = SEV_NONE;

        // Level 1 - Warning
        // Temperature approaching limit
        
        if (temp_warning) begin
            fault_detected = 1'b1;
            fault_severity = SEV_WARNING;
        end

        
        // Level 2 - Recoverable
        if (rail_5v_fault ||
            payload_oc_fault ||
            fpga_ot_fault ||
            comm_timeout_fault ||
            payload_failure_fault) begin

            fault_detected = 1'b1;
            fault_severity = SEV_RECOVERABLE;
        end

        // Level 3 - Critical
        if (battery_uv_fault ||
            battery_ov_fault ||
            obc_timeout) begin

            fault_detected = 1'b1;
            fault_severity = SEV_CRITICAL;
        end

    end

endmodule
