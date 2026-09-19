module watchdog #(
    parameter integer TIMEOUT_COUNT = 100
)(
    input  wire clk,
    input  wire reset,

    // OBC heartbeat signal
    input  wire obc_heartbeat,

    // 1 = OBC heartbeat timeout detected
    output reg  obc_timeout
);

    
    // Heartbeat synchronizer

    reg heartbeat_sync1;
    reg heartbeat_sync2;
    reg heartbeat_previous;

    
    // Watchdog counter
  

    reg [31:0] watchdog_count;

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            heartbeat_sync1  <= 1'b0;
            heartbeat_sync2  <= 1'b0;
            heartbeat_previous <= 1'b0;

            watchdog_count   <= 32'd0;
            obc_timeout      <= 1'b0;

        end

        else begin

            
            // Synchronize heartbeat
            

            heartbeat_sync1 <= obc_heartbeat;
            heartbeat_sync2 <= heartbeat_sync1;

          
            // Detect rising edge of heartbeat

            heartbeat_previous <= heartbeat_sync2;

            if ((heartbeat_sync2 == 1'b1) &&
                (heartbeat_previous == 1'b0)) begin

                // OBC is alive
                watchdog_count <= 32'd0;
                obc_timeout    <= 1'b0;

            end

            // No heartbeat

            else begin

                if (watchdog_count < TIMEOUT_COUNT)
                    watchdog_count <= watchdog_count + 1'b1;

                // Timeout reached
              

                if (watchdog_count >= TIMEOUT_COUNT - 1) begin
                    obc_timeout <= 1'b1;
                end

            end

        end

    end

endmodule
