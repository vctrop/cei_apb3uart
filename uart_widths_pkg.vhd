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
	
package uart_widths_pkg is
	-- System bus widths
	constant APB_DATA_WIDTH_c : natural := 32;
	constant APB_ADDR_WIDTH_c : natural := 32;
	-- Peripheral register widths
	constant UART_BAUD_WIDTH_c : natural := 16;
	constant UART_DATA_WIDTH_c : natural := 8;
end package uart_widths_pkg;


package body uart_widths_pkg is

end package body uart_widths_pkg;