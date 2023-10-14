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
	
package pkg_uart_constants is
	-- APB bus widths
	constant APB_DATA_WIDTH_c   : natural := 32;
	constant APB_ADDR_WIDTH_c   : natural := 32;
	
	-- Tx and Rx FIFOs
	-- FIFO size's base-2 exponent (size = 2 ** size_e)
	constant UART_FIFO_SIZE_E_c : natural := 8;                -- 256
	-- FIFO word width
	constant UART_FIFO_WIDTH_c  : natural := 8;
	
	-- Memory-mapped registers 
	-- Addresses are aligned with 32-bit words 
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
	constant UART_INT_WIDTH_c    : natural := 6;
	
	-- Register addresses
	constant UART_DATA_ADDR_c    : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000000";
	constant UART_FBAUD_ADDR_c   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000004";
	constant UART_CTRL_ADDR_c    : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000008";
	constant UART_INTEN_ADDR_c   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"0000000C";
	constant UART_INTPEND_ADDR_c : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000010";
	
	-- Register reset values
	-- Control register masks
	-- Data, error and interrupt pending registers do not have configurable reset values
	constant UART_FBAUD_SIM_c    : integer range 0 to 2**UART_FBAUD_WIDTH_c - 1   := 255;
	constant UART_CTRL_RSTVL_c   : std_logic_vector(UART_CTRL_WIDTH_c-1 downto 0) := "01111111" &           -- Rx FIFO watermark = 127
	                                                                                 "01111111" &           -- Tx FIFO watermark = 127
	                                                                                 '0' &                  -- Odd parity
	                                                                                 '1' &                  -- Parity enable
	                                                                                 '1';                   -- 2 stop bits
	constant UART_INTEN_RSTVL_c  : std_logic_vector(UART_INT_WIDTH_c-1 downto 0)  := "001000";              -- Only enable Rx FIFO empty interrupt
	
end package pkg_uart_constants;


package body pkg_uart_constants is

end package body pkg_uart_constants;