----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.10.2023 03:07:46
-- Design Name: 
-- Module Name: tb_uart_tx_rx - behavioral
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

entity tb_uart_tx_rx is
end tb_uart_tx_rx;

architecture behavioral of tb_uart_tx_rx is
	-- Clock and reset
	constant half_clk_period : time := 10 ns;
	constant clk_period : time := 2*half_clk_period;
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';
	-- Tx
	signal data_av_tx_s : std_logic := '0';
	signal address_s : std_logic_vector(1 downto 0) := (others => '0');
	signal data_in_tx_s : std_logic_vector(15 downto 0) := (others => '0');
	signal tx_s      : std_logic;
	signal ready_s   : std_logic;
	-- Rx
	signal data_out_rx_s : std_logic_vector(7 downto 0);
	signal data_av_rx_s  : std_logic;
	signal rx_s      : std_logic;
begin
	-- Clock and reset
	clk <= not clk after half_clk_period;
	rst <= '0' after 5*clk_period;
	
	DUV_tx: entity work.uart_tx(behavioral)
	generic map(
		TX_DATA_ADDR     => "00",
		BAUD_DIV_ADDR   => "10",
		BAUD_DIV_DEFAULT => x"0004"
	)
	port map(
		clk       => clk,
		rst       => rst,
		-- inputs
		data_av_i => data_av_tx_s,
		address_i => address_s,
		data_i    => data_in_tx_s,
		-- outputs
		tx_o      => tx_s,
		ready_o  	=> ready_s
	);
	
	DUV_rx: entity work.uart_rx(behavioral)
	generic map(
		-- FREQ_BAUD_ADDR => "10",
		-- TX_DATA_ADDR   => "00",
		BAUD_DIV_DEFAULT => x"0004"
	)
	port map(
		clk       => clk,
		rst       => rst,
		-- inputs
		rx_i      => rx_s,
		baud_av_i => '0',
		baud_i    => (others => '0'),
		-- outputs
		data_o    => data_out_rx_s,
		data_av_o => data_av_rx_s
	);
	
	--
	
	rx_s <= tx_s;
	
	process
	begin
		wait until rst = '0';
		wait for clk_period;
		address_s <= "00";
		data_in_tx_s <= x"5555";
		data_av_tx_s <= '1';
		
		wait for clk_period;
		data_av_tx_s <= '0';
		
		wait until ready_s = '1';
	
	end process;
end behavioral;
