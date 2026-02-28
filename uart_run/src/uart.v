module uart #(
    parameter CLKS_PER_BIT = 87 // 10MHz / 115200
) (
    input clk,
    input rst_n,
    input rx,
    output reg tx,
    input [7:0] tx_data,
    input tx_en,
    output reg tx_busy,
    output reg [7:0] rx_data,
    output reg rx_valid
);

// TX Logic
reg [7:0] tx_shift;
reg [3:0] tx_bit_cnt;
reg [15:0] tx_clk_cnt;
reg [1:0] tx_state; // 0=IDLE, 1=START, 2=DATA, 3=STOP

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx <= 1'b1;
        tx_busy <= 1'b0;
        tx_state <= 2'b00;
        tx_clk_cnt <= 0;
        tx_bit_cnt <= 0;
        tx_shift <= 0;
    end else begin
        case (tx_state)
            2'b00: begin // IDLE
                tx <= 1'b1;
                tx_clk_cnt <= 0;
                tx_bit_cnt <= 0;
                if (tx_en && !tx_busy) begin
                    tx_busy <= 1'b1;
                    tx_shift <= tx_data;
                    tx_state <= 2'b01; // START
                end
            end
            2'b01: begin // START
                tx <= 1'b0;
                if (tx_clk_cnt < CLKS_PER_BIT - 1) begin
                    tx_clk_cnt <= tx_clk_cnt + 1;
                end else begin
                    tx_clk_cnt <= 0;
                    tx_state <= 2'b10; // DATA
                end
            end
            2'b10: begin // DATA
                tx <= tx_shift[0];
                if (tx_clk_cnt < CLKS_PER_BIT - 1) begin
                    tx_clk_cnt <= tx_clk_cnt + 1;
                end else begin
                    tx_clk_cnt <= 0;
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    if (tx_bit_cnt < 7) begin
                        tx_bit_cnt <= tx_bit_cnt + 1;
                    end else begin
                        tx_state <= 2'b11; // STOP
                        tx_bit_cnt <= 0;
                    end
                end
            end
            2'b11: begin // STOP
                tx <= 1'b1;
                if (tx_clk_cnt < CLKS_PER_BIT - 1) begin
                    tx_clk_cnt <= tx_clk_cnt + 1;
                end else begin
                    tx_clk_cnt <= 0;
                    tx_state <= 2'b00; // IDLE
                    tx_busy <= 1'b0;
                end
            end
        endcase
    end
end

// RX Logic
reg [1:0] rx_state; // 0=IDLE, 1=START, 2=DATA, 3=STOP
reg [15:0] rx_clk_cnt;
reg [3:0] rx_bit_cnt;
reg [7:0] rx_shift;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_state <= 2'b00;
        rx_clk_cnt <= 0;
        rx_bit_cnt <= 0;
        rx_shift <= 0;
        rx_data <= 0;
        rx_valid <= 0;
    end else begin
        case (rx_state)
            2'b00: begin // IDLE
                rx_valid <= 0;
                rx_clk_cnt <= 0;
                rx_bit_cnt <= 0;
                if (rx == 1'b0) begin // start bit detected
                    rx_state <= 2'b01;
                end
            end
            2'b01: begin // START
                if (rx_clk_cnt < (CLKS_PER_BIT / 2) - 1) begin
                    rx_clk_cnt <= rx_clk_cnt + 1;
                end else begin
                    if (rx == 1'b0) begin
                        rx_clk_cnt <= 0;
                        rx_state <= 2'b10;
                    end else begin
                        rx_state <= 2'b00;
                    end
                end
            end
            2'b10: begin // DATA
                if (rx_clk_cnt < CLKS_PER_BIT - 1) begin
                    rx_clk_cnt <= rx_clk_cnt + 1;
                end else begin
                    rx_clk_cnt <= 0;
                    rx_shift <= {rx, rx_shift[7:1]};
                    if (rx_bit_cnt < 7) begin
                        rx_bit_cnt <= rx_bit_cnt + 1;
                    end else begin
                        rx_bit_cnt <= 0;
                        rx_state <= 2'b11;
                    end
                end
            end
            2'b11: begin // STOP
                if (rx_clk_cnt < CLKS_PER_BIT - 1) begin
                    rx_clk_cnt <= rx_clk_cnt + 1;
                end else begin
                    rx_clk_cnt <= 0;
                    rx_data <= rx_shift;
                    rx_valid <= 1'b1;
                    rx_state <= 2'b00;
                end
            end
        endcase
    end
end

endmodule
