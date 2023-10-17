-- Copyright Centro Espacial ITA (Instituto Tecnológico de Aeronáutica).
-- This source describes Open Hardware and is licensed under the CERN-OHLS v2
-- You may redistribute and modify this documentation and make products
-- using it under the terms of the CERN-OHL-S v2 (https:/cern.ch/cern-ohl).
-- This documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED
-- WARRANTY, INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY
-- AND FITNESS FOR A PARTICULAR PURPOSE. Please see the CERN-OHL-S v2
-- for applicable conditions.
-- Source location: https://github.com/vctrop/cei_apb3uart
-- As per CERN-OHL-S v2 section 4, should You produce hardware based on
-- these sources, You must maintain the Source Location visible on any
-- product you make using this documentation.

library ieee;
	use ieee.std_logic_1164.all;
	-- use ieee.numeric_std.all;

-- 
	use work.pkg_apbuart.all;

entity tb_dp_fifo is
end tb_dp_fifo;

architecture behavioral of tb_dp_fifo is
	-- Clock and reset
	constant half_clk_period : time := 10 ns;
	constant clk_period      : time := 2*half_clk_period;
	signal clk  : std_logic  := '0';
	signal rstn : std_logic  := '0';
	
	-- FIFO data push/pop
	signal fifo_push_s : std_logic := '0';
	signal fifo_pop_s  : std_logic := '0';
	signal fifo_in_s   : std_logic_vector(UART_DATA_WIDTH_c-1 downto 0) := (others => '0');
	signal fifo_out_s  : std_logic_vector(UART_DATA_WIDTH_c-1 downto 0) := (others => '0');
	
	-- FIFO status
	signal fifo_full_s  : std_logic;
	signal fifo_empty_s : std_logic;
	signal fifo_usage_s : std_logic_vector(UART_FIFO_SIZE_E_c downto 0);
	
begin
	-- Clock and reset
	clk <= not clk after half_clk_period;
	rstn <= '1' after 5*clk_period;
	
	DUV: entity work.dp_fifo(behavioral)
	generic map(
		FIFO_SIZE_E => UART_FIFO_SIZE_E_c,
		FIFO_WIDTH  => UART_FIFO_WIDTH_c,
		EDAC_WIDTH  => FIFO_EDAC_WIDTH_EN_c,
		ENABLE_EDAC => FIFO_ENABLE_EDAC_c
	)
	port map(
	-- Clock and reset (active low)
	clk     => clk,
	rstn    => rstn,
	-- Write port
	push_i  => fifo_push_s,
	data_i  => fifo_in_s,
	-- Read port
	pop_i   => fifo_pop_s,
	data_o  => fifo_out_s,
	-- Status
	full_o  => fifo_full_s,
	empty_o => fifo_empty_s,
	usage_o => fifo_usage_s
	);
	
	TEST: process
	begin
		wait until rstn = '1';
		
		-- FIFO TEST (w/ SIZE_E = 2):
		-- 1) pop from empty fifo
		-- 2) push until fifo is full
		-- 3) pop from full fifo
		-- 4) push to make it full but after a circular increment
		-- 5) simultaneous push and pop with full fifo
		-- 6) endlessly pop
		
		-- 1) pop from empty fifo
		wait for clk_period;
		fifo_push_s <= '0';
		fifo_pop_s  <= '1';
		
		-- 2) push until fifo is full
		wait for clk_period;
		fifo_in_s   <= x"55";
		fifo_push_s <= '1';
		fifo_pop_s  <= '0';
		
		wait for clk_period;
		fifo_in_s   <= x"AA";
		fifo_push_s <= '1';
		fifo_pop_s  <= '0';
		
		wait for clk_period;
		fifo_in_s   <= x"FF";
		fifo_push_s <= '1';
		fifo_pop_s  <= '0';
		
		wait for clk_period;
		fifo_in_s   <= x"11";
		fifo_push_s <= '1';
		fifo_pop_s  <= '0';
		
		-- 3) pop from full fifo
		wait for clk_period;
		fifo_push_s <= '0';
		fifo_pop_s  <= '1';
		
		-- 4) push to make it full but after a circular increment
		wait for clk_period;
		fifo_in_s   <= x"55";
		fifo_push_s <= '1';
		fifo_pop_s  <= '0';
		
		-- 5) simultaneous push and pop with full fifo
		wait for clk_period;
		fifo_in_s   <= x"66";
		fifo_push_s <= '1';
		fifo_pop_s  <= '1';
	
		-- 6) endlessly pop
		wait for clk_period;
		fifo_in_s   <= x"66";
		fifo_push_s <= '0';
		fifo_pop_s  <= '1';
	
	end process;
	
end behavioral;