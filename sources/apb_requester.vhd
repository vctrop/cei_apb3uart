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

entity apb_requester is
	generic (
		-- Bus widths
		APB_DATA_WIDTH : natural range 8 to 32 := APB_DATA_WIDTH_c;
		APB_ADDR_WIDTH : natural range 8 to 32 := APB_ADDR_WIDTH_c;
		-- Number of peripherals
		NUM_PERIPH     : natural range 1 to 16 := REQ_NUM_PERIPH_c;
		-- AMBA version configuration
		AMBA_VERSION : std_logic_vector(REQ_NUM_PERIPH_c-1 downto 0) := AMBA_VERSION_c
	);
	port (
		-- Clock and reset (active low)
		clk  : in std_logic;
		rstn : in std_logic;
		
		-- Interrupt bus
		interrupt_i : in std_logic_vector(NUM_PERIPH-1 downto 0);
		
		-- APB COMPLETER SIGNALS
		prdata_i  : in slv_array_t(NUM_PERIPH-1 downto 0);
		pready_i  : in std_logic_vector(NUM_PERIPH-1 downto 0);          -- APB3 only
		pslverr_i : in std_logic_vector(NUM_PERIPH-1 downto 0);          -- APB3 only
				
		-- APB REQUESTER SIGNALS
		paddr_o   : out std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
		psel_o    : out std_logic_vector(NUM_PERIPH-1 downto 0);
		penable_o : out std_logic;
		pwrite_o  : out std_logic;
		pwdata_o  : out std_logic_vector(APB_DATA_WIDTH-1 downto 0)
	);
end apb_requester;

architecture behavioral of apb_requester is
	-- FSM state register
	type fsm_state_t is (
	                     Sread_idle,               -- read transfer IDLE state, waiting for interrupt
	                     Sread_setup,              -- read transfer SETUP state
	                     Sread_access,             -- read transfer ACCESS state
	                     Swrite_idle,              -- write transfer IDLE state
	                     Swrite_setup,             -- write transfer SETUP state
	                     Swrite_access             -- write transfer ACCESS state
	);
	signal reg_state : fsm_state_t;

	-- AMBA 3 APB
	signal reg_pwdata : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal reg_prdata : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	
	-- 
	signal paddr_s   : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
	signal psel_s    : std_logic_vector(NUM_PERIPH-1 downto 0);
	signal psel_int_s: std_logic_vector(NUM_PERIPH-1 downto 0);
	signal penable_s : std_logic;
	signal pwrite_s  : std_logic;
	signal pwdata_s  : std_logic_vector(APB_DATA_WIDTH-1 downto 0);

	-- Inverted version of the data read from peripheral
	signal prdata_inv_s : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	
	-- Interrupt priory encoder
	-- Still synthesizable because ieee.math_real is only used at synthesis time
	-- signal reg_int_id : unsigned(integer(ceil(log2(real(NUM_PERIPH))))-1 downto 0);
	signal reg_int_id : unsigned(f_log2(NUM_PERIPH)-1 downto 0);
	
	-- AMBA version-dependent FSM state transitions
	signal Sraccess_to_Swidle_s : std_logic_vector(NUM_PERIPH-1 downto 0);
	signal Sraccess_to_Sridle_s : std_logic_vector(NUM_PERIPH-1 downto 0);
	signal Swaccess_to_Sridle_s : std_logic_vector(NUM_PERIPH-1 downto 0);

  -- Configuration-specific constants
	-- CURRENTLY HARDCODED TO THE x"00000000" ADDRESS
	constant ADDR_APBUART0_C : std_logic_vector(APB_DATA_WIDTH-1 downto 0) := x"00000000";
	constant AMBA_VERSION_C  : std_logic_vector(NUM_PERIPH-1 downto 0) := AMBA_VERSION(NUM_PERIPH-1 downto 0);
	
begin
	-- AMBA version handling:
	-- Bit i in AMBA_VERSION indicates the version of the i-th peripheral (0 for AMBA 2, 1 for AMBA 3)
	-- APB 3 considers pready in the state transition, while APB 2 does not 
	Sraccess_to_Swidle_s <= (not AMBA_VERSION_C) or (pready_i and (not pslverr_i)) when reg_state = Sread_access else (others => '0');
	Sraccess_to_Sridle_s <= AMBA_VERSION_C and pready_i and pslverr_i when reg_state = Sread_access else (others => '0');
	Swaccess_to_Sridle_s <= (not AMBA_VERSION_C) or pready_i when reg_state = Swrite_access else (others => '0');
	
	CONTROL_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then 
				reg_pwdata <= (others => '0');
				reg_state <= Sread_idle;
				
			else 
				-- 
				case reg_state is
					
					-- APB3 READ TRANSACTION - IDLE STATE
					when Sread_idle =>
						-- Check interrupts
						if unsigned(interrupt_i) /= 0 then
							
							-- Priority encoder for peripherals' interrupts
							-- Peripheral with indices 0 and NUM_PERIPH-1 having the highest and lowest priority, respectively 
							for i in NUM_PERIPH-1 downto 0 loop
								if interrupt_i(i) = '1' then
									reg_int_id <= to_unsigned(i, reg_int_id'length);
								end if;
							end loop;
							
							-- Next state
							reg_state <= Sread_setup;
						else
							-- Next state
							reg_state <= Sread_idle;
						end if;

					-- APB3 READ TRANSACTION - SETUP STATE
					when Sread_setup =>
						-- Next state
						reg_state <= Sread_access;
	
					-- APB3 READ TRANSACTION - ACCESS STATE 
					when Sread_access =>
						-- APB 3 considers pready and pslverr in the state transition, while APB 2 does not 
						if Sraccess_to_Swidle_s(to_integer(reg_int_id)) = '1' then
							reg_prdata <= prdata_i(to_integer(reg_int_id));
							-- Next state
							reg_state <= Swrite_idle;
						elsif Sraccess_to_Sridle_s(to_integer(reg_int_id)) = '1' then
							-- Next state
							reg_state <= Sread_idle;
						else
							-- Next state
							reg_state <= Sread_access;
						end if;

					-- APB3 WRITE TRANSACTION - IDLE STATE
					when Swrite_idle =>
						-- Output write data
						reg_pwdata <= not reg_prdata;
						-- Next state
						reg_state <= Swrite_setup;

					-- APB3 WRITE TRANSACTION - SETUP STATE
					when Swrite_setup =>
						-- Next state
						reg_state <= Swrite_access;

					-- APB3 WRITE TRANSACTION - ACCESS STATE
					when Swrite_access =>
						-- Next state
						if Swaccess_to_Sridle_s(to_integer(reg_int_id)) = '1' then
							reg_state <= Sread_idle;
						else
							reg_state <= Swrite_access;
						end if;

				end case;		
			end if;
		end if;
	end process;
	
	
		-- NanoXplore syntesis tool did not like (to_integer(reg_int_id) => '1', others => '0')
	GEN_ONE_HOT: for i in psel_int_s'range generate
		psel_int_s(i) <= '1' when (i = to_integer(reg_int_id)) else '0';
	end generate;
	
	-- Control outputs
	psel_s    <= psel_int_s when reg_state = Sread_setup or reg_state = Swrite_setup or
												       reg_state = Sread_access or reg_state = Swrite_access else (others => '0');									 
	penable_s <= '1' when reg_state = Sread_access or reg_state = Swrite_access else '0';
	pwrite_s  <= '1' when reg_state = Swrite_setup or reg_state = Swrite_access else '0';

	-- Address (combinational and hardwired)
	paddr_s   <= ADDR_APBUART0_C;

	-- Registered outputs
	pwdata_s  <= reg_pwdata;

	-- 
	psel_o    <= psel_s;
	penable_o <= penable_s;
	pwrite_o  <= pwrite_s;
	paddr_o   <= paddr_s;
	pwdata_o  <= pwdata_s;

end behavioral;