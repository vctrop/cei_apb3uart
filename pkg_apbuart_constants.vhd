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
	
package pkg_apbuart_constants is
	-- AMBA
	-- Bus widths
	constant APB_DATA_WIDTH_c : natural := 32;
	constant APB_ADDR_WIDTH_c : natural := 32;
	
	-- Number of peripherals
	constant REQ_NUM_PERIPH_c : natural := 1;
	
	-- AMBA version of each peripheral, indexed by the interruption priority encoder
	-- Each beat corresponds to a peripheral, and HIGH means AMBA 3 while LOW means AMBA 2
	constant AMBA_VERSION_c   : std_logic_vector(REQ_NUM_PERIPH_c-1 downto 0) := (others => '1');
	

	-- Memory-mapped registers
	-- 0x00 (r/w) UART data transmission/reception double register (tx: write-onlye, rx: read-only)
	-- 0x04 (r/w) UART frequency/baud ratio register: threshold for clock counter (16 bits, configurable) - floor(clk_freq/baud_rate)
	-- 0x08 (r/w) UART control register
	--      [0]     Stop bit: LOW for one, high for TWO stop bits
	--      [1]     Parity enable
	--      [2]     Parity select: LOW for odd, HIGH for even
	--      [3-10]  Tx FIFO watermark
	--      [11-18] Rx FIFO watermark
	-- 0x0C (r/w) UART interrupt enable
	--      [0] (future) Tx FIFO full
	--      [1] (future) Rx FIFO full
	--      [2] (future) Tx FIFO empty
	--      [3] (future) Rx FIFO empty
	--      [4] (future) Tx FIFO positions occupied < watermark
	--      [5] (future) Rx FIFO positions occupied > watermark
	-- 0x10 (r/-) UART interrupt pending register - read-only and driven by the conditions alone
	--      [0] (future) Tx FIFO full
	--      [1] (future) Rx FIFO full
	--      [2] (future) Tx FIFO empty
	--      [3] (future) Rx FIFO empty
	--      [4] (future) Tx FIFO positions occupied < watermark
	--      [5] (future) Rx FIFO positions occupied > watermark
	
	-- Register widths
	constant UART_DATA_WIDTH_c   : natural := 8;
	constant UART_FBAUD_WIDTH_c  : natural := 16;
	constant UART_CTRL_WIDTH_c   : natural := 19;
	constant UART_NUM_INT_c      : natural := 6;
	
	-- Register addresses are aligned with 32-bit words
	constant UART_DATA_ADDR_c    : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000000";
	constant UART_FBAUD_ADDR_c   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000004";
	constant UART_CTRL_ADDR_c    : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000008";
	constant UART_INTEN_ADDR_c   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"0000000C";
	constant UART_INTPEND_ADDR_c : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000010";
	
	-- Register reset values for simulation
	constant UART_FBAUD_SIM_c    : natural range 0 to 2**UART_FBAUD_WIDTH_c - 1   := 255;
	constant UART_CTRL_RSTVL_c   : std_logic_vector(UART_CTRL_WIDTH_c-1 downto 0) := "01111111" &         -- Rx FIFO watermark = 127
	                                                                                 "01111111" &         -- Tx FIFO watermark = 127
	                                                                                 '0' &                -- Odd/even parity selector
	                                                                                 '0' &                -- Parity disable
	                                                                                 '0';                 -- 1 stop bits
																																									 
																																									 
	constant INVERTER_CHAIN_LENGTH_RSTVL_c : natural := 2;
	
	-- UART Tx and Rx FIFOs
	-- FIFO size's base-2 exponent (size = 2 ** size_e)
	constant UART_FIFO_SIZE_E_c : natural := 6;                         -- Tx and Rx FIFOs w/ 64 bytes each
	
	-- FIFO word width
	constant UART_FIFO_WIDTH_c  : natural := 8;

	-- FIFO EDAC enabled
	constant FIFO_ENABLE_EDAC_c : std_logic := '1';
	constant FIFO_DISABLE_EDAC_c : std_logic := '0';
	constant FIFO_EDAC_WIDTH_EN_c  : natural := 6;
	constant FIFO_EDAC_WIDTH_DIS_c  : natural := 0;
	
	-- Constants for specific use cases
	---- Rx FIFO empty interrupt mask
	constant INT_RX_FIFO_EMPTY_c : std_logic_vector(UART_NUM_INT_c-1 downto 0)  := "001000"; 
	
	-- Types
	type slv_array_t is array (natural range <>) of std_logic_vector(APB_DATA_WIDTH_c-1 downto 0); 
	
	-- Functions
	function f_log2 (x : positive) return natural;
	
end package pkg_apbuart_constants;

package body pkg_apbuart_constants is

	-- Modified log2 which returns f_log2(1) = 1
	function f_log2 (x : positive) return natural is
		variable i : natural;
	begin
	
		if (x = 1) then
			i := 1;
		else
			i := 0;
			while (2**i < x) and i < 31 loop
				i := i + 1;
			end loop;
		end if;
		
		return i;

	end function;

end package body pkg_apbuart_constants;