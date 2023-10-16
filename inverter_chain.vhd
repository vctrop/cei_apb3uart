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
	use ieee.numeric_std.all;
	-- use ieee.math_real.ceil;
	-- use ieee.math_real.log2;

-- 
	use work.pkg_apbuart_constants.all;

entity inverter_chain is
	generic (
			-- Number of inverters in the chain
		CHAIN_LENGTH     : natural range 2 to 100 := INVERTER_CHAIN_LENGTH_RSTVL_c;
		-- Frequency/baud ratio of the UART controllers: floor(clk_freq/baud_rate)
		UART_FBAUD_RSTVL : natural := UART_FBAUD_SIM_c;
		-- UART Tx and Rx FIFOs
		UART_FIFO_SIZE_E  : natural range 0 to 10 := UART_FIFO_SIZE_E_c;                                -- UART FIFOs size = 2^FIFO_SIZE_E
		FIFO_EDAC_WIDTH   : natural range 0 to 16 := FIFO_EDAC_WIDTH_EN_c;
		FIFO_ENABLE_EDAC  : std_logic             := FIFO_ENABLE_EDAC_c
	);
	port (
		-- Clock and reset (active low)
		clk  : in std_logic;
		rstn : in std_logic;
		-- UART
		rx_i : in std_logic;
		tx_o : out std_logic
	);
end inverter_chain;

architecture behavioral of inverter_chain is

	signal chain_rx_s : std_logic_vector(CHAIN_LENGTH-1 downto 0);
	signal chain_tx_s : std_logic_vector(CHAIN_LENGTH-1 downto 0);
	
begin
	
	-- Drive UART inverter chain input
	chain_rx_s(0) <= rx_i;
	
	-- Loop indices with rx as reference
	GEN_INV: for i in 0 to CHAIN_LENGTH-1 generate
	
		-- Connect one inverter tx to the next rx
		UART_INV: entity work.uart_inverter(behavioral)
		generic map(
			UART_FBAUD_RSTVL => UART_FBAUD_RSTVL,
			UART_FIFO_SIZE_E => UART_FIFO_SIZE_E,
			FIFO_EDAC_WIDTH  => FIFO_EDAC_WIDTH,
			FIFO_ENABLE_EDAC => FIFO_ENABLE_EDAC
		)
		port map(
			-- Clock and reset (active low)
			clk  => clk,
			rstn => rstn,
			-- UART
			rx_i => chain_rx_s(i),
			tx_o => chain_tx_s(i)
		);
	end generate;
	
	GEN_CONNECT: for i in 0 to CHAIN_LENGTH-2 generate
		chain_rx_s(i+1) <= chain_tx_s(i);
	end generate;
	
	-- Drive UART inverter chain output
	tx_o <= chain_tx_s(CHAIN_LENGTH-1);

end behavioral;