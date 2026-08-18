-- Simple 8-bit SPI Master (Mode 0: CPOL=0, CPHA=0)
-- Synthesizable with GHDL + Yosys for IHP SG13G2 flow

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        start    : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        rx_data  : out std_logic_vector(7 downto 0);
        busy     : out std_logic;
        done     : out std_logic;
        sclk     : out std_logic;
        mosi     : out std_logic;
        miso     : in  std_logic;
        cs_n     : out std_logic
    );
end entity spi_master;

architecture rtl of spi_master is
    type state_type is (ST_IDLE, ST_TRANSFER, ST_FINISH);
    signal state    : state_type;
    signal bit_cnt  : integer range 0 to 7;
    signal shift_tx : std_logic_vector(7 downto 0);
    signal shift_rx : std_logic_vector(7 downto 0);
    signal clk_div  : std_logic;
begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state    <= ST_IDLE;
            bit_cnt  <= 0;
            shift_tx <= (others => '0');
            shift_rx <= (others => '0');
            rx_data  <= (others => '0');
            busy     <= '0';
            done     <= '0';
            sclk     <= '0';
            mosi     <= '0';
            cs_n     <= '1';
            clk_div  <= '0';
        elsif rising_edge(clk) then
            done <= '0';
            case state is
                when ST_IDLE =>
                    sclk <= '0';
                    cs_n <= '1';
                    busy <= '0';
                    if start = '1' then
                        state    <= ST_TRANSFER;
                        busy     <= '1';
                        cs_n     <= '0';
                        shift_tx <= tx_data;
                        bit_cnt  <= 7;
                        mosi     <= tx_data(7);
                        clk_div  <= '0';
                    end if;

                when ST_TRANSFER =>
                    clk_div <= not clk_div;
                    if clk_div = '0' then
                        -- Rising edge of sclk -> Sample MISO
                        sclk     <= '1';
                        shift_rx <= shift_rx(6 downto 0) & miso;
                    else
                        -- Falling edge of sclk -> Shift MOSI
                        sclk <= '0';
                        if bit_cnt = 0 then
                            state   <= ST_FINISH;
                            rx_data <= shift_rx;
                        else
                            bit_cnt <= bit_cnt - 1;
                            mosi    <= shift_tx(bit_cnt - 1);
                        end if;
                    end if;

                when ST_FINISH =>
                    sclk  <= '0';
                    cs_n  <= '1';
                    busy  <= '0';
                    done  <= '1';
                    state <= ST_IDLE;

                when others =>
                    state <= ST_IDLE;
            end case;
        end if;
    end process;

end architecture rtl;
