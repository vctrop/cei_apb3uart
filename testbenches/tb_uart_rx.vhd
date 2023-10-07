----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.10.2023 03:07:46
-- Design Name: 
-- Module Name: tb_uart_rx - behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee;
	use ieee.std_logic_1164.all;
	-- use ieee.numeric_std.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture behavioral of tb_uart_rx is
	-- Clock and reset
	constant half_clk_period : time := 10 ns;
	constant clk_period : time := 2*half_clk_period;
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';
	-- 
	signal rx_s       : std_logic := '1';
	signal baud_av_s  : std_logic := '0';
	signal baud_in_s  : std_logic_vector(15 downto 0);
	signal data_out_s : std_logic_vector(7 downto 0);
	signal data_av_s  : std_logic;
	
begin
	-- Clock and reset
	clk <= not clk after half_clk_period;
	rst <= '0' after 5*clk_period;
	
	DUV: entity work.uart_rx(behavioral)
	generic map(
		-- FREQ_BAUD_ADDR => "10",
		-- TX_DATA_ADDR   => "00",
		BAUD_DIV_DEFAULT => x"0001"
	)
	port map(
		clk       => clk,
		rst       => rst,
		-- inputs
		rx_i      => rx_s,
		baud_av_i => baud_av_s,
		baud_i    => baud_in_s,
		-- outputs
		data_o    => data_out_s,
		data_av_o => data_av_s
	);
	
	--
	process
	begin
		wait until rst = '0';
		wait for clk_period;
		rx_s <= '0';
		wait for clk_period;
		rx_s <= '0';
		wait for clk_period;
		rx_s <= '1';
		wait for clk_period;
		rx_s <= '0';
		wait for clk_period;
		rx_s <= '1';
		wait for clk_period;
		rx_s <= '0';
		wait for clk_period;
		rx_s <= '1';
		wait for clk_period;
		rx_s <= '0';
		wait for clk_period;
		rx_s <= '1';
		wait for clk_period;
		rx_s <= '0';
		wait for clk_period;
		rx_s <= '1';
		wait until data_av_s = '1';
	
	end process;
end behavioral;
