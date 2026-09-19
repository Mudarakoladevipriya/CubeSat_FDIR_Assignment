module uart_interface #(
    parameter integer CLK_FREQ = 10_000_000,
    parameter integer BAUD_RATE = 9600,
    parameter [7:0] FAULT_CLEAR_CMD = 8'hCC
)(
    input  wire       clk,
    input  wire       reset,

    // UART pins
    input  wire       uart_rx,
    output reg        uart_tx,

    // Fault register
    input  wire [7:0] fault_status,

    // Transmit control
    input  wire       tx_start,
    output reg        tx_busy,

    // Receive status
    output reg        rx_valid,
    output reg [7:0]  rx_data,

    // Fault clear pulse
    output reg        fault_clear
);

    // Number of clock cycles per UART bit
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // UART RX synchronizer

    reg rx_sync1;
    reg rx_sync2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end
        else begin
            rx_sync1 <= uart_rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // UART RX
    // 8 data bits, no parity, 1 stop bit
  

    localparam RX_IDLE  = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA  = 3'd2;
    localparam RX_STOP  = 3'd3;
    localparam RX_DONE  = 3'd4;

    reg [2:0] rx_state;
    reg [31:0] rx_clk_count;
    reg [2:0] rx_bit_count;
    reg [7:0] rx_shift_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_state     <= RX_IDLE;
            rx_clk_count <= 0;
            rx_bit_count <= 0;
            rx_shift_reg <= 8'b0;
            rx_valid     <= 1'b0;
            rx_data      <= 8'b0;
            fault_clear  <= 1'b0;
        end
        else begin

            rx_valid    <= 1'b0;
            fault_clear <= 1'b0;

            case (rx_state)

                RX_IDLE: begin
                    rx_clk_count <= 0;
                    rx_bit_count <= 0;

                    // Start bit detected
                    if (rx_sync2 == 1'b0) begin
                        rx_state     <= RX_START;
                        rx_clk_count <= 0;
                    end
                end

                RX_START: begin
                    // Sample middle of start bit
                    if (rx_clk_count == (CLKS_PER_BIT/2)-1) begin

                        if (rx_sync2 == 1'b0) begin
                            rx_state     <= RX_DATA;
                            rx_clk_count <= 0;
                            rx_bit_count <= 0;
                        end
                        else begin
                            rx_state <= RX_IDLE;
                        end

                    end
                    else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end
                end

                RX_DATA: begin

                    if (rx_clk_count == CLKS_PER_BIT-1) begin

                        rx_clk_count <= 0;

                        // UART sends LSB first
                        rx_shift_reg[rx_bit_count] <= rx_sync2;

                        if (rx_bit_count == 3'd7) begin
                            rx_state <= RX_STOP;
                        end
                        else begin
                            rx_bit_count <= rx_bit_count + 1;
                        end

                    end
                    else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end

                end

                RX_STOP: begin

                    if (rx_clk_count == CLKS_PER_BIT-1) begin

                        rx_clk_count <= 0;
                        rx_state     <= RX_DONE;

                    end
                    else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end

                end

                RX_DONE: begin

                    rx_data  <= rx_shift_reg;
                    rx_valid <= 1'b1;

                    // Special command from OBC
                    if (rx_shift_reg == FAULT_CLEAR_CMD)
                        fault_clear <= 1'b1;

                    rx_state <= RX_IDLE;

                end

                default: begin
                    rx_state <= RX_IDLE;
                end

            endcase
        end
    end

    // UART TX
    // 8 data bits, no parity, 1 stop bit

    localparam TX_IDLE  = 3'd0;
    localparam TX_START = 3'd1;
    localparam TX_DATA  = 3'd2;
    localparam TX_STOP  = 3'd3;

    reg [2:0] tx_state;
    reg [31:0] tx_clk_count;
    reg [2:0] tx_bit_count;
    reg [7:0] tx_shift_reg;

    always @(posedge clk or posedge reset) begin

        if (reset) begin
            tx_state     <= TX_IDLE;
            tx_clk_count <= 0;
            tx_bit_count <= 0;
            tx_shift_reg <= 8'b0;
            uart_tx      <= 1'b1;
            tx_busy      <= 1'b0;
        end

        else begin

            case (tx_state)

                TX_IDLE: begin

                    uart_tx      <= 1'b1;
                    tx_busy      <= 1'b0;
                    tx_clk_count <= 0;
                    tx_bit_count <= 0;

                    if (tx_start) begin

                        tx_shift_reg <= fault_status;
                        tx_busy      <= 1'b1;
                        tx_state     <= TX_START;

                    end

                end

                TX_START: begin

                    uart_tx <= 1'b0;

                    if (tx_clk_count == CLKS_PER_BIT-1) begin

                        tx_clk_count <= 0;
                        tx_bit_count <= 0;
                        tx_state     <= TX_DATA;

                    end
                    else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end

                end

                TX_DATA: begin

                    // LSB first
                    uart_tx <= tx_shift_reg[tx_bit_count];

                    if (tx_clk_count == CLKS_PER_BIT-1) begin

                        tx_clk_count <= 0;

                        if (tx_bit_count == 3'd7) begin
                            tx_state <= TX_STOP;
                        end
                        else begin
                            tx_bit_count <= tx_bit_count + 1;
                        end

                    end
                    else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end

                end

                TX_STOP: begin

                    uart_tx <= 1'b1;

                    if (tx_clk_count == CLKS_PER_BIT-1) begin

                        tx_clk_count <= 0;
                        tx_busy      <= 1'b0;
                        tx_state     <= TX_IDLE;

                    end
                    else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end

                end

                default: begin
                    tx_state <= TX_IDLE;
                    uart_tx  <= 1'b1;
                    tx_busy  <= 1'b0;
                end

            endcase

        end
    end

endmodule
