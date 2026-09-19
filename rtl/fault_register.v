
module fault_register (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] fault_events,
    input  wire       fault_clear,

    output reg  [7:0] fault_status
);

    always @(posedge clk or posedge reset) begin

        if (reset) begin
            fault_status <= 8'b0;
        end

        else if (fault_clear) begin
            fault_status <= 8'b0;
        end

        else begin
            fault_status <= fault_status | fault_events;
        end

    end

endmodule
