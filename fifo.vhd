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

-- work library 	
use work.pkg_fifo_constants.all;

entity fifo is
	generic (
		-- FIFO size  = 2 ** FIFO_SIZE_E
		FIFO_SIZE_E : natural range 0 to 7  := FIFO_SIZE_E_c;
		FIFO_WIDTH  : natural range 1 to 32 := FIFO_WIDTH_c
	);
	port (
		-- Clock and reset (active low)
		clk     : in std_logic;
		rstn    : in std_logic;
		-- Write port
		push_i  : in std_logic;
		data_i  : in std_logic_vector(FIFO_WIDTH_c-1 downto 0);
		-- Read port
		pop_i   : in std_logic;
		data_o  : out std_logic_vector(FIFO_WIDTH_c-1 downto 0);
	  -- Status
		full_o  : out std_logic;
		empty_o : out std_logic;
		usage_o : out std_logic_vector(FIFO_SIZE_E_c downto 0)
	);
end fifo;

architecture behavioral of fifo is
	-- FIFO memory declaration
	type slv_array_t is array (natural range <>) of std_logic_vector(FIFO_WIDTH-1 downto 0); 
	signal regs_fifo : slv_array_t(2**FIFO_SIZE_E downto 0);
	
	-- Read/write indices registers
	signal reg_windex : unsigned(FIFO_SIZE_E-1 downto 0);
	signal reg_rindex : unsigned(FIFO_SIZE_E-1 downto 0);
	
	-- -- Read/write indices registers
	-- -- Use extra bit strategy to distinguish between fifo-empty and fifo-full conditions
	-- signal reg_windex : unsigned(FIFO_SIZE_E downto 0);
	-- signal reg_rindex : unsigned(FIFO_SIZE_E downto 0);
	
	-- FIFO usage register (goes from 0 to FIFO_SIZE)
	signal reg_usage : unsigned(FIFO_SIZE_E downto 0);
	
	-- Status signals
	signal fifo_empty_s : std_logic;
	signal fifo_full_s  : std_logic;

begin
	-- Determine FIFO status with FIFO usage register
	fifo_empty_s <= '1' when reg_usage = to_unsigned(0, reg_usage'length) else '0';
	fifo_full_s  <= '1' when reg_usage = to_unsigned(FIFO_SIZE_E**2, reg_usage'length) else '0';
	
	-- Determine FIFO status with the extra bit strategy
	-- fifo_empty_s <= '1' when reg_rindex(FIFO_SIZE_E-1 downto 0) = reg_windex(FIFO_SIZE_E-2 downto 0) and
                           -- reg_rindex(FIFO_SIZE_E)          = reg_windex(FIFO_SIZE_E-1)	else '0';
	-- fifo_full_s  <= '1' when reg_rindex(FIFO_SIZE_E-1 downto 0) = reg_windex(FIFO_SIZE_E-2 downto 0) and
                           -- reg_rindex(FIFO_SIZE_E)         /= reg_windex(FIFO_SIZE_E-1)	else '0';
	
	-- Manage FIFO push and pop
	FIFO: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then 
				regs_fifo  <= (others => (others => '0'));
				reg_windex <= (others => '0');
				reg_rindex <= (others => '0');
				reg_usage  <= (others => '0');
			else
				-- FIFO data_i push
				if (push_i and not fifo_full_s) = '1' then
					regs_fifo(to_integer(reg_windex)) <= data_i;
					-- Naturaly-circular increment of write index
					reg_windex <= reg_windex + 1;
					-- Exclusive push
					if pop_i = '0' then
						reg_usage <= reg_usage + 1;
					end if;
				end if;
				
				-- FIFO data_o pop
				if (pop_i and not fifo_empty_s) = '1' then
					-- Naturaly-circular increment of read index
					reg_rindex <= reg_rindex + 1;
					-- Exclusive pop
					if push_i = '0' then
						reg_usage <= reg_usage - 1;
					end if;
				end if;
				
			end if;
		end if;
	end process;
	
	-- Drive outputs
	data_o  <= regs_fifo(to_integer(reg_rindex)) when rstn = '1' else (others => '0');
	full_o  <= fifo_full_s when rstn = '1' else '0';
	empty_o <= fifo_empty_s when rstn = '1' else '0';
	usage_o <= std_logic_vector(reg_usage) when rstn = '1' else (others => '0');

end behavioral;