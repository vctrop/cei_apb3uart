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
	use ieee.numeric_std.all;
	use ieee.std_logic_1164.all;

use work.uart_widths_pkg.all;

entity apb_uart is
	generic (
		-- Width of the APB data bus
		APB_DATA_WIDTH : natural := APB_DATA_WIDTH_c;
		-- Width of the address bus
		APB_ADDR_WIDTH : natural := APB_ADDR_WIDTH_c;
		-- Reset values for the peripheral's memory-mapped registers
		UART_BAUD_RSTV : std_logic_vector(UART_BAUD_WIDTH_c-1 downto 0) := (0 => '1', others => '0');
		UART_DATA_RSTV : std_logic_vector(UART_DATA_WIDTH_c-1 downto 0) := (others => '0')
	);
	port(
		-- Clock and negated reset
		clk       : std_logic;
		rstn      : std_logic;
		
		-- AMBA 3 APB
		paddr_i   : in std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
		psel_i    : in std_logic;
		penable_i : in std_logic;
		pwrite_i  : in std_logic;
		pwdata_i  : in std_logic_vector(APB_DATA_WIDTH-1 downto 0);
		prdata_o  : out std_logic_vector(APB_DATA_WIDTH-1 downto 0);
		pready_o  : out std_logic;
		pslverr_o : out std_logic;
		
		-- UART 
		rx_i      : in std_logic;
		tx_o      : out std_logic;
		-- cts_i     : in std_logic;
		-- rts_o     : out std_logic;
		
		-- Interrupt
		int_o     : out std_logic
	);
end apb_uart;

architecture behavioral of apb_uart is
	-- AMBA APB
	-- APB finite state machine
	type fsm_state_apb_t is(Sapb_idle, Sapb_setup, Sapb_access);
	signal reg_state_apb : fsm_state_apb_t;

	-- APB I/O registers
	signal reg_paddr  : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
	
	-- Associated signals
	signal address_exists_s : std_logic;
	
	-- Memory-mapped registers
	-- Addresses are aligned with 32-bit words 
	-- 0x00 - UART data transmission register (8 bits)
	-- 0x04 - UART frequency/baud ratio register: threshold for clock counter (16 bits) - floor(clk_freq/baud_rate)
	-- 0x08 (future) UART status register
	-- 0x0C (future) UART configuration register
	constant UART_DATA_ADDR_c : std_logic_vector(APB_ADDR_WIDTH-1 downto 0) := x"00000000";
	constant UART_BAUD_ADDR_c : std_logic_vector(APB_ADDR_WIDTH-1 downto 0) := x"00000004";
	-- Registers
	signal reg_uart_data_tx : std_logic_vector(UART_DATA_WIDTH_c-1 downto 0);
	signal reg_uart_data_rx : std_logic_vector(UART_DATA_WIDTH_c-1 downto 0);
	signal reg_uart_baud    : std_logic_vector(UART_BAUD_WIDTH_c-1 downto 0);
	-- Associated signals
	signal uart_data_rx_s : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal uart_baud_s    : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
	
	-- UART
	-- Tx and Rx finite state machines
	type fsm_state_uart_t is (Suart_idle, Suart_start_bit, Suart_data_bits, Suart_stop_bit);
	signal reg_state_tx : fsm_state_uart_t;
	signal reg_state_rx : fsm_state_uart_t;
	
	-- Clock counters for baud generation
	signal reg_clk_counter_tx : integer range 0 to 65535;
	signal reg_clk_counter_rx : integer range 0 to 65535;

	-- Bit counters for data transmission and reception
	signal reg_bit_counter_tx : integer range 0 to 8;						-- MODIFICAR PARA PARIDADE
	signal reg_bit_counter_rx : integer range 0 to 8;           -- MODIFICAR PARA PARIDADE

begin
	-- AMBA APB FSM
	APB_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- Memory-mapped registers
				reg_uart_data_rx <= UART_DATA_RSTV;
				-- reg_uart_data_tx <= UART_DATA_RSTV;
				reg_uart_baud    <= UART_BAUD_RSTV;
				-- State registers
				reg_state_apb    <= Sapb_idle;
			else
				-- 
				case reg_state_apb is
				
					-- APB3 IDLE STATE
					when Sapb_idle =>
						-- Wait for psel_i
						if psel_i = '1' then
							-- Keep address
						  reg_paddr <= paddr_i;
							
							-- APB write to Tx data register
							if pwrite_i = '1' and paddr_i = UART_DATA_ADDR_c then
								reg_uart_data_tx <= pwdata_i(UART_DATA_WIDTH_c-1 downto 0);
							-- APB write to frequency/baud ratio
							elsif pwrite_i = '1' and paddr_i = UART_BAUD_ADDR_c then
								reg_uart_baud <= pwdata_i(UART_BAUD_WIDTH_c-1 downto 0);
							end if;
							
							-- Next state
							reg_state_apb <= Sapb_setup;
						else
							-- Next state
							reg_state_apb <= Sapb_idle;
						end if;

					-- APB3 SETUP STATE
					when Sapb_setup =>
						reg_state_apb <= Sapb_access;
						
					-- APB3 ACCESS STATE
					when Sapb_access =>
						reg_state_apb <= Sapb_idle;

				end case;
			end if;
		end if;
	end process;
	
	
	-- -- UART Rx FSM
	-- UARTRX_FSM: process(clk)
	-- begin
		-- if rising_edge(clk) then
			-- if rst = '1' then
				-- reg_state_rx <= Suart_idle;
			-- else
				-- case reg_state_rx is
					-- when => 


				-- end case;
			-- end if;
		-- end if;
	-- end process;

	-- -- UART Tx FSM
	-- UARTTX_FSM: process(clk)
	-- begin
		-- if rising_edge(clk) then
			-- if rst = '1' then
				-- reg_state_tx <= Suart_idle;
			-- else
				-- case reg_state_tx is
					-- when => 
					

				-- end case;
			-- end if;
		-- end if;
	-- end process;	

	-- Drive APB outputs
	-- Assembly APB-width signals
	uart_data_rx_s(APB_DATA_WIDTH_c-1 downto UART_DATA_WIDTH_c) <= (others => '0');
	uart_data_rx_s(UART_DATA_WIDTH_c-1 downto 0) <= reg_uart_data_rx;
	uart_baud_s(APB_DATA_WIDTH_c-1 downto UART_BAUD_WIDTH_c) <= (others => '0');
	uart_baud_s(UART_BAUD_WIDTH_c-1 downto 0) <= reg_uart_baud;
	
	prdata_o  <= uart_data_rx_s when reg_state_apb = Sapb_setup and pwrite_i = '0' and reg_paddr = UART_DATA_ADDR_c else
	             uart_baud_s when reg_state_apb = Sapb_setup and pwrite_i = '0' and reg_paddr = UART_BAUD_ADDR_c else
	             (others => '0');
  
	
	-- Peripherals with fixed 2-cycle access can tie PREADY
	pready_o <= '1';
	
	-- 
	address_exists_s <= '1' when reg_state_apb = Sapb_setup and (reg_paddr = UART_BAUD_ADDR_c or reg_paddr = UART_DATA_ADDR_c) else '0';
	pslverr_o <= '1' when reg_state_apb = Sapb_setup and address_exists_s = '0' else '0';
	
	-- Drive UART outputs
	tx_o <= '0';
	int_o <= '0';

end behavioral;