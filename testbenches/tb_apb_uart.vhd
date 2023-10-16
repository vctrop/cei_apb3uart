-- Copyright Centro Espacial ITA (Instituto Tecnológico de Aeronáutica).
-- This source describes Open Hardware and is licensed under the CERN-OHLS v2
-- You may redistribute and modify this documentation and make products
-- using it under the terms of the CERN-OHL-S v2 (https:/cern.ch/cern-ohl).
-- This documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED
-- WARRANTY, INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY
-- AND FITNESS FOR A PARTICULAR PURPOSE. Please see the CERN-OHL-S v2
-- for applicable conditions.
-- Source location: https://github.com/vctrop/apb_uart
-- As per CERN-OHL-S v2 section 4, should You produce hardware based on
-- these sources, You must maintain the Source Location visible on any
-- product you make using this documentation.

library ieee;
	use ieee.std_logic_1164.all;
	-- use ieee.numeric_std.all;

--
	use work.pkg_apbuart_constants.all;

entity tb_apb_uart is
end tb_apb_uart;

architecture behavioral of tb_apb_uart is
	-- Clock and reset
	constant half_clk_period : time := 10 ns;
	constant clk_period      : time := 2*half_clk_period;
	signal clk : std_logic   := '0';
	signal rstn : std_logic  := '0';
	
	-- APB Requester signals
	signal prdata_s  : std_logic_vector(APB_DATA_WIDTH_c-1 downto 0);
	signal pready_s  : std_logic;
	signal pslverr_s : std_logic;
	
		-- APB Completer signals
	signal paddr_s   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := (others => '0');
	signal psel_s    : std_logic := '0';
	signal penable_s : std_logic := '0';
	signal pwrite_s  : std_logic := '0';
	signal pwdata_s  : std_logic_vector(APB_DATA_WIDTH_c-1 downto 0);
	
	-- UART signals
	signal uart_rxi_s : std_logic := '0';
	signal uart_txo_s : std_logic;
	signal int_s      : std_logic;
	
	
begin
	-- Clock and reset
	clk <= not clk after half_clk_period;
	rstn <= '1' after 5*clk_period;
	
	DUV: entity work.apb_uart(behavioral)
	generic map(
		UART_FBAUD_RSTVL => UART_FBAUD_SIM_c,                             -- Frequency/baud ratio of the UART controllers: floor(clk_freq/baud_rate)
		UART_FIFO_SIZE_E => UART_FIFO_SIZE_E_c,                           -- Exponent for the UART FIFO sizes. FIFO_SIZE = 2^FIFO_SIZE_E
		FIFO_EDAC_WIDTH  => FIFO_EDAC_WIDTH_EN_c,
		FIFO_ENABLE_EDAC => FIFO_ENABLE_EDAC_c
	)
	port map(
		-- Clock and reset (active low)
		clk       => clk,
		rstn      => rstn,
		
		-- AMBA 3 APB
		paddr_i   => paddr_s,
		psel_i    => psel_s,
		penable_i => penable_s,
		pwrite_i  => pwrite_s,
		pwdata_i  => pwdata_s,
		prdata_o  => prdata_s,
		pready_o  => pready_s,
		pslverr_o => pslverr_s,
		
		-- UART 
		rx_i      => uart_rxi_s,
		tx_o      => uart_txo_s,
		
		-- Interrupt
		int_o     => int_s
	);
	-- Test UART in loopback mode 
	-- Does not work with generic NUM_PERIPH, DATA_WIDTH and ADDR_WIDTH
	uart_rxi_s <= uart_txo_s;
	
	APB_PROC: process
	begin
		wait until rstn = '1';
			pwdata_s <= x"00000055";
			-- APB writes to the data register
		for i in 0 to 255 loop
			
			-- Setup phase
			wait for clk_period;
			paddr_s   <= x"00000000";
			pwrite_S  <= '1';
			psel_s    <= '1';
			penable_s <= '0';
			pwdata_s  <= not pwdata_s;       -- Begin sending AA and getting 55
			-- Access phase
			wait for clk_period;
			penable_s <= '1';
			-- Idle phase
			wait for clk_period;
			psel_s    <= '0';
			penable_s <= '0';
			pwrite_s  <= '0';	
			
		end loop;
		
		-- -- APB reads from the data register
		-- for i in 0 to 255 loop
			
			-- -- Wait interrupt (currently Rx fifo not empty)
			-- wait until int_s = '0';
			-- -- Setup phase
			-- wait for clk_period;
			-- paddr_s   <= x"00000000";
			-- pwrite_S  <= '0';
			-- psel_s    <= '1';
			-- penable_s <= '0';
			-- -- Access phase
			-- wait for clk_period;
			-- penable_s <= '1';
			-- -- Idle phase
			-- wait for clk_period;
			-- psel_s    <= '0';
			-- penable_s <= '0';
			
		-- end loop;
		
	end process;
	
end behavioral;