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
	-- use ieee.numeric_std.all;
	
package uart_constants_pkg is
	-- System bus widths
	constant APB_DATA_WIDTH_c   : natural := 32;
	constant APB_ADDR_WIDTH_c   : natural := 32;
	
	-- Peripheral interrupt width
	constant PERIPH_INT_WIDTH_c : natural := 2;
	
	-- Memory-mapped register widths
	constant UART_DATA_WIDTH_c  : natural := 8;
	constant UART_FBAUD_WIDTH_c : natural := 16;
	-- Frequency/baud value for simulation
	constant UART_FBAUD_SIM_c   : natural := 4;                           
	
	-- Memory-mapped register addresses
	-- Addresses are aligned with 32-bit words 
	-- 0x00 - UART data transmission register (8 bits)
	-- 0x04 - UART frequency/baud ratio register: threshold for clock counter (16 bits) - floor(clk_freq/baud_rate)
	-- 0x08 (future) UART status register
	-- 0x0C (future) UART configuration register
	constant UART_DATA_ADDR_c : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000000";
	constant UART_BAUD_ADDR_c : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := x"00000004";

end package uart_constants_pkg;


package body uart_constants_pkg is

end package body uart_constants_pkg;