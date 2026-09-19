module protection_fsm (
    input  wire       clk,
    input  wire       reset,

    input  wire       fault_detected,
    input  wire [1:0] fault_severity,
    input  wire       fault_clear,

    output reg        payload_enable,
    output reg        safe_mode
);

    // Severity levels
    localparam SEV_NONE        = 2'b00;
    localparam SEV_WARNING     = 2'b01;
    localparam SEV_RECOVERABLE = 2'b10;
    localparam SEV_CRITICAL    = 2'b11;

    // FSM states
    localparam INIT           = 3'b000;
    localparam MONITOR        = 3'b001;
    localparam FAULT_ANALYSIS = 3'b010;
    localparam PROTECT        = 3'b011;
    localparam SAFE_MODE      = 3'b100;
    localparam RECOVERY       = 3'b101;
    localparam LATCH          = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    // State register

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= INIT;
        else
            state <= next_state;
    end

    
    // Next-state logic

    always @(*) begin

        next_state = state;

        case (state)

            INIT: begin
                next_state = MONITOR;
            end

            MONITOR: begin
                if (fault_detected)
                    next_state = FAULT_ANALYSIS;
            end

            FAULT_ANALYSIS: begin

                if (fault_severity == SEV_CRITICAL)
                    next_state = SAFE_MODE;

                else if (fault_severity == SEV_RECOVERABLE)
                    next_state = PROTECT;

                else
                    next_state = MONITOR;

            end

            PROTECT: begin
    // Keep payload disabled while recoverable fault is active.
    // Return to recovery only after the fault condition is cleared.
    if (!fault_detected)
        next_state = RECOVERY;
    else
        next_state = PROTECT;
    end

            SAFE_MODE: begin
                // Critical fault goes to latched protection
                next_state = LATCH;
            end

            RECOVERY: begin
                // Return to normal monitoring
                next_state = MONITOR;
            end

            LATCH: begin
                // Stay here until explicit FAULT_CLEAR
                if (fault_clear)
                    next_state = RECOVERY;
            end

            default: begin
                next_state = INIT;
            end

        endcase
    end

    // Output logic

    always @(*) begin

        // Default: normal operation
        payload_enable = 1'b1;
        safe_mode      = 1'b0;

        case (state)

            INIT: begin
                payload_enable = 1'b1;
                safe_mode      = 1'b0;
            end

            MONITOR: begin
                payload_enable = 1'b1;
                safe_mode      = 1'b0;
            end

            FAULT_ANALYSIS: begin
                payload_enable = 1'b1;
                safe_mode      = 1'b0;
            end

            PROTECT: begin
                // Disable affected payload
                payload_enable = 1'b0;
                safe_mode      = 1'b0;
            end

            SAFE_MODE: begin
                // Critical fault
                payload_enable = 1'b0;
                safe_mode      = 1'b1;
            end

            RECOVERY: begin
                // Controlled return to monitoring
                payload_enable = 1'b1;
                safe_mode      = 1'b0;
            end

            LATCH: begin
                // Remain protected
                payload_enable = 1'b0;
                safe_mode      = 1'b1;
            end

            default: begin
                payload_enable = 1'b1;
                safe_mode      = 1'b0;
            end

        endcase
    end

endmodule
