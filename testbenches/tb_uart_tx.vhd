----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.10.2023 03:07:46
-- Design Name: 
-- Module Name: tb_uart_tx - behavioral
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

entity tb_uart_tx is
end tb_uart_tx;

architecture behavioral of tb_uart_tx is
	-- Clock and reset
	constant half_clk_period : time := 10 ns;
	constant clk_period : time := 2*half_clk_period;
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';
	-- 
	signal data_av_s : std_logic;
	signal address_s : std_logic_vector(1 downto 0);
	signal data_in_s : std_logic_vector(15 downto 0);
	signal tx_s      : std_logic;
	signal ready_s   : std_logic;
	
begin
	-- Clock and reset
	clk <= not clk after half_clk_period;
	rst <= '0' after 5*clk_period;
	
	DUV: entity work.uart_tx(behavioral)
	generic map(
		BAUD_DIV_DEFAULT => x"0001",
		BAUD_DIV_ADDR   => "10",
		TX_DATA_ADDR     => "00"
	)
	port map(
		clk       => clk,
		rst       => rst,
		-- inputs
		data_av_i => data_av_s,
		address_i => address_s,
		data_i    => data_in_s,
		-- outputs
		tx_o      => tx_s,
		ready_o  	=> ready_s
	);
	
	--
	process
	begin
		wait until rst = '0';
		wait for clk_period;
		address_s <= "00";
		data_in_s <= x"5555";
		data_av_s <= '1';
		
		wait for clk_period;
		data_av_s <= '0';
		
		wait until ready_s = '1';
	
	end process;
end behavioral;
