// Simple 8-bit SPI Master (Mode 0: CPOL=0, CPHA=0)
// Compatible with Yosys / LibreLane / IHP SG13G2 flow

`default_nettype none

module spi_master (
    input  wire       clk,        // System Clock
    input  wire       rst_n,      // Active-low asynchronous reset
    input  wire       start,      // Trigger transmission
    input  wire [7:0] tx_data,    // Data to transmit
    output reg  [7:0] rx_data,    // Received data
    output reg        busy,       // High during SPI transfer
    output reg        done,       // 1-cycle pulse when transfer completes
    output reg        sclk,       // SPI Serial Clock output
    output reg        mosi,       // Master Out Slave In
    input  wire       miso,       // Master In Slave Out
    output reg        cs_n        // Active-low Chip Select
);

    // State encoding
    localparam IDLE      = 2'b00;
    localparam TRANSFER  = 2'b01;
    localparam FINISH    = 2'b10;

    reg [1:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_tx;
    reg [7:0] shift_rx;
    reg       clk_div;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            bit_cnt  <= 3'd0;
            shift_tx <= 8'd0;
            shift_rx <= 8'd0;
            rx_data  <= 8'd0;
            busy     <= 1'b0;
            done     <= 1'b0;
            sclk     <= 1'b0;
            mosi     <= 1'b0;
            cs_n     <= 1'b1;
            clk_div  <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    sclk <= 1'b0;
                    cs_n <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        state    <= TRANSFER;
                        busy     <= 1'b1;
                        cs_n     <= 1'b0;
                        shift_tx <= tx_data;
                        bit_cnt  <= 3'd7;
                        mosi     <= tx_data[7];
                        clk_div  <= 1'b0;
                    end
                end

                TRANSFER: begin
                    clk_div <= ~clk_div;
                    if (!clk_div) begin
                        // Rising edge of sclk -> Sample MISO
                        sclk     <= 1'b1;
                        shift_rx <= {shift_rx[6:0], miso};
                    end else begin
                        // Falling edge of sclk -> Shift MOSI
                        sclk <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            state   <= FINISH;
                            rx_data <= shift_rx;
                        end else begin
                            bit_cnt  <= bit_cnt - 1'b1;
                            mosi     <= shift_tx[bit_cnt - 1'b1];
                        end
                    end
                end

                FINISH: begin
                    sclk <= 1'b0;
                    cs_n <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
