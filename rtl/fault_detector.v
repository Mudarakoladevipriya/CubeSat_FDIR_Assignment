module fault_detector #(
    parameter integer PERSISTENCE_COUNT = 10
)(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] battery_voltage,
    input  wire [9:0] rail_5v,
    input  wire [9:0] payload_current,

    // FPGA temperature in degrees C
    input  wire [7:0] fpga_temperature,
    input  wire       comm_status,
    input  wire       payload_status,


    output reg        battery_uv_fault,
    output reg        battery_ov_fault,
    output reg        rail_5v_fault,
    output reg        payload_oc_fault,
    output reg        fpga_ot_fault,
    output reg        comm_timeout_fault,
    output reg        payload_failure_fault,

    // Temperature warning
    output reg        temp_warning
);

  

    reg [31:0] battery_uv_count;
    reg [31:0] battery_ov_count;

    reg [31:0] rail_5v_count;

    reg [31:0] payload_oc_count;

    reg [31:0] temperature_count;

    reg [31:0] comm_count;

    reg [31:0] payload_failure_count;
   
    // BATTERY + 5V RAIL + PAYLOAD CURRENT + TEMPERATURE
 

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            battery_uv_count       <= 0;
            battery_ov_count       <= 0;
            rail_5v_count          <= 0;
            payload_oc_count       <= 0;
            temperature_count      <= 0;

            battery_uv_fault       <= 1'b0;
            battery_ov_fault       <= 1'b0;
            rail_5v_fault          <= 1'b0;
            payload_oc_fault       <= 1'b0;
            fpga_ot_fault          <= 1'b0;

            temp_warning           <= 1'b0;

        end

        else begin

        
            // 1. BATTERY UNDER-VOLTAGE
            // Fault when battery < 7.0 V
          

            if (battery_voltage < 8'd70) begin

                if (battery_uv_count < PERSISTENCE_COUNT)
                    battery_uv_count <= battery_uv_count + 1;

                if (battery_uv_count >= PERSISTENCE_COUNT - 1)
                    battery_uv_fault <= 1'b1;

            end

            else begin

                battery_uv_count <= 0;
                battery_uv_fault <= 1'b0;

            end


          
            // 2. BATTERY OVER-VOLTAGE
            // Fault when battery > 8.4 V
         

            if (battery_voltage > 8'd84) begin

                if (battery_ov_count < PERSISTENCE_COUNT)
                    battery_ov_count <= battery_ov_count + 1;

                if (battery_ov_count >= PERSISTENCE_COUNT - 1)
                    battery_ov_fault <= 1'b1;

            end

            else begin

                battery_ov_count <= 0;
                battery_ov_fault <= 1'b0;

            end


          
            // 3. 5V RAIL FAULT
            // Fault when < 4.75 V OR > 5.25 V
          

            if ((rail_5v < 10'd475) ||
                (rail_5v > 10'd525)) begin

                if (rail_5v_count < PERSISTENCE_COUNT)
                    rail_5v_count <= rail_5v_count + 1;

                if (rail_5v_count >= PERSISTENCE_COUNT - 1)
                    rail_5v_fault <= 1'b1;

            end

            else begin

                rail_5v_count <= 0;
                rail_5v_fault <= 1'b0;

            end


          
            // 4. PAYLOAD OVER-CURRENT
            // Fault when current > 2 A
          

            if (payload_current > 10'd200) begin

                if (payload_oc_count < PERSISTENCE_COUNT)
                    payload_oc_count <= payload_oc_count + 1;

                if (payload_oc_count >= PERSISTENCE_COUNT - 1)
                    payload_oc_fault <= 1'b1;

            end

            else begin

                payload_oc_count <= 0;
                payload_oc_fault <= 1'b0;

            end


          
            // 5. FPGA TEMPERATURE
            // Fault when temperature > 85 C
            

            if (fpga_temperature > 8'd85) begin

                if (temperature_count < PERSISTENCE_COUNT)
                    temperature_count <= temperature_count + 1;

                if (temperature_count >= PERSISTENCE_COUNT - 1)
                    fpga_ot_fault <= 1'b1;

            end

            else begin

                temperature_count <= 0;
                fpga_ot_fault <= 1'b0;

            end


        
            // TEMPERATURE WARNING
          
            // 80 C is used here as a design assumption for
            // "approaching the limit".
      

            if ((fpga_temperature >= 8'd80) &&
                (fpga_temperature <= 8'd85))

                temp_warning <= 1'b1;

            else
                temp_warning <= 1'b0;

        end

    end


    
    // 6. COMMUNICATION TIMEOUT
    
    // comm_status = 1 -> valid communication
    // comm_status = 0 -> invalid/no valid communication
  
    // Fault is generated only when the invalid condition
    // persists for PERSISTENCE_COUNT clocks.
    

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            comm_count         <= 0;
            comm_timeout_fault <= 1'b0;

        end

        else begin

            if (comm_status == 1'b0) begin

                if (comm_count < PERSISTENCE_COUNT)
                    comm_count <= comm_count + 1;

                if (comm_count >= PERSISTENCE_COUNT - 1)
                    comm_timeout_fault <= 1'b1;

            end

            else begin

                comm_count         <= 0;
                comm_timeout_fault <= 1'b0;

            end

        end

    end


    
    // 7. PAYLOAD STATUS FAILURE
  
    // payload_status = 1 -> healthy
    // payload_status = 0 -> failure
  
    // Fault is generated only when failure persists.
  

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            payload_failure_count <= 0;
            payload_failure_fault <= 1'b0;

        end

        else begin

            if (payload_status == 1'b0) begin

                if (payload_failure_count < PERSISTENCE_COUNT)
                    payload_failure_count <=
                        payload_failure_count + 1;

                if (payload_failure_count >= PERSISTENCE_COUNT - 1)
                    payload_failure_fault <= 1'b1;

            end

            else begin

                payload_failure_count <= 0;
                payload_failure_fault <= 1'b0;

            end

        end

    end

endmodule
