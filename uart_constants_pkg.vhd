-- Copyright Centro Espacial ITA (Instituto Tecnológico de Aeronáutica).
-- This source describes Open Hardware and is licensed under the CERN-OHLS v2
-- You may redistribute and modify this documentation and make products
-- using it under the terms of the CERN-OHL-S v2 (https:/cern.ch/cern-ohl).
-- This documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED
-- WARRANTY, INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY
-- AND FITNESS FOR A PARTICULAR PURPOSE. Please see the CERN-OHL-S v2
-- for applicable conditions.
-- Source location: https://github.com/vctrop/AMBA_playground
-- As per CERN-OHL-S v2 section 4, should You produce hardware based on
-- these sources, You must maintain the Source Location visible on any
-- product you make using this documentation.

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	
package uart_constants_pkg is
	-- System bus widths
	constant APB_DATA_WIDTH_c   : natural := 32;
	constant APB_ADDR_WIDTH_c   : natural := 32;
	
	-- Peripheral interrupt width
	constant PERIPH_INT_WIDTH_c : natural := 3;
	
	-- Memory-mapped registers 
	-- Addresses are aligned with 32-bit words 
	-- 0x00 - UART data transmission register (8 bits)
	-- 0x04 - UART control register (1 bit)
	---- [0] - Stop bit: LOW for one, high for TWO stop bits.
	---- [1] - Parity enable: LOW for [no parity bit], HIGH for [parity bit].
	---- [2] - Parity select: LOW for odd, HIGH for even.
	-- 0x08 - UART frequency/baud ratio register: threshold for clock counter (16 bits, configurable) - floor(clk_freq/baud_rate)
	-- 0x0C (future) UART status register
	-- Register widths
	constant UART_DATA_WIDTH_c  : natural := 8;
	constant UART_CTRL_WIDTH_c  : natural := 3;
	constant UART_FBAUD_WIDTH_c : natural := 16;
	-- Register addresses
	constant UART_DATA_ADDR_c   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000000";
	constant UART_CTRL_ADDR_c   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000004";
	constant UART_FBAUD_ADDR_c  : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000008";
	-- Register reset values    
	constant UART_FBAUD_SIM_c   : integer range 0 to 2**UART_FBAUD_WIDTH_c - 1   := 255;
	constant UART_CTRL_RSTVL_c  : std_logic_vector(UART_CTRL_WIDTH_c-1 downto 0) := "110"; 
	
end package uart_constants_pkg;


package body uart_constants_pkg is

end package body uart_constants_pkg;