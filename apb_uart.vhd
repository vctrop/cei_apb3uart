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

use work.uart_constants_pkg.all;

entity apb_uart is
	generic (
		APB_DATA_WIDTH  : natural range 0 to 32               := APB_DATA_WIDTH_c;    -- Width of the APB data bus
		APB_ADDR_WIDTH  : natural range 0 to 32               := APB_ADDR_WIDTH_c;    -- Width of the address bus
		UART_FBAUD_RSTV : natural range 0 to UART_FBAUD_MAX_c := UART_FBAUD_SIM_c    -- Frequency/baud ratio reset value
	);
	port(
		-- Clock and negated reset
		clk       : std_logic;
		rstn      : std_logic;
		-- AMBA 3 APB
		paddr_i   : in std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0);
		psel_i    : in std_logic;
		penable_i : in std_logic;
		pwrite_i  : in std_logic;
		pwdata_i  : in std_logic_vector(APB_DATA_WIDTH_c-1 downto 0);
		prdata_o  : out std_logic_vector(APB_DATA_WIDTH_c-1 downto 0);
		pready_o  : out std_logic;
		pslverr_o : out std_logic;
		-- UART 
		uart_rx_i : in std_logic;
		uart_tx_o : out std_logic;
		-- Interrupt
		int_o     : out std_logic_vector(PERIPH_INT_WIDTH_c-1 downto 0)
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
	signal reg_tx_data    : std_logic_vector(UART_DATA_WIDTH_c-1 downto 0);
	signal reg_rx_data    : std_logic_vector(UART_DATA_WIDTH_c-1 downto 0);
	signal reg_fbaud      : std_logic_vector(UART_FBAUD_WIDTH_c-1 downto 0);
	-- Associated signals
	signal uart_data_rx_s : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal uart_baud_s    : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
	
	-- UART
	-- Tx and Rx finite state machines
	type fsm_state_uart_t is (Suart_idle, Suart_start_bit, Suart_data_bits, Suart_stop_bit);
	signal reg_state_tx   : fsm_state_uart_t;
	signal reg_state_rx   : fsm_state_uart_t;
	
	-- Clock counters for baud generation
	signal reg_clk_count_tx : integer range 0 to UART_FBAUD_MAX_c;
	signal reg_clk_count_rx : integer range 0 to UART_FBAUD_MAX_c;

	-- Bit counters for data transmission and reception
	-- FUTURO: Modificar para paridade?
	-- FUTURO: Tornar parametrizável entre 5 e 9?
	signal reg_bit_count_tx : integer range 0 to 8;						-- MODIFICAR PARA PARIDADE
	signal reg_bit_count_rx : integer range 0 to 8;           -- MODIFICAR PARA PARIDADE
	
	-- Rx sampling indicator
	signal rx_sampling_s : std_logic;

begin
	-- AMBA APB FSM
	APB_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- Memory-mapped registers driven by APB (write registers)
				reg_tx_data   <= (others => '0');
				reg_fbaud     <= std_logic_vector(to_unsigned(UART_FBAUD_RSTV, reg_fbaud'length));
				-- State register
				reg_state_apb <= Sapb_idle;
			else
				case reg_state_apb is
				
					-- APB3 IDLE STATE
					when Sapb_idle =>
						-- Wait for psel_i
						if psel_i = '1' then
							-- Keep address
						  reg_paddr <= paddr_i;
							-- APB writes to memory-mapped registers
							-- UART data Tx register
							if pwrite_i = '1' and paddr_i = UART_DATA_ADDR_c then
								reg_tx_data <= pwdata_i(UART_DATA_WIDTH_c-1 downto 0);
							-- UART frequency/baud ratio register
							elsif pwrite_i = '1' and paddr_i = UART_BAUD_ADDR_c then
								reg_fbaud <= pwdata_i(UART_FBAUD_WIDTH_c-1 downto 0);
							end if;
							-- Next state
							reg_state_apb <= Sapb_setup;
						else
							-- Next state
							reg_state_apb <= Sapb_idle;
						end if;

					-- APB3 SETUP STATE
					when Sapb_setup =>
						-- Next state
						reg_state_apb <= Sapb_access;
						
					-- APB3 ACCESS STATE
					when Sapb_access =>
						-- Next state
						reg_state_apb <= Sapb_idle;

				end case;
			end if;
		end if;
	end process;
	
	-- UART Rx FSM
	-- Samples at the middle of the interval;
	-- Sampling period is T = (1/clk_freq) * reg_fbaud
	-- FUTURE: sample multiple times and do a voting
	rx_sampling_s <= '1' when reg_clk_count_rx = to_integer(unsigned(reg_fbaud))/2 else '0';

	UARTRX_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- Memory-mapped register driven by UART Rx (read-only from APB)
				reg_rx_data <= (others => '0');
				-- UART Rx registers
				reg_clk_count_rx <= 0;
				reg_bit_count_rx <= 0;
				-- FSM state register
				reg_state_rx <= Suart_idle;
			else
				case reg_state_rx is

					-- UART RX IDLE STATE
					when Suart_idle =>
						-- 
						reg_clk_count_rx <= 0;
						reg_bit_count_rx <= 0;
						-- Detect start bit
						if uart_rx_i = '0' then
							-- Next state
							reg_state_rx <= Suart_start_bit;
						else
							-- Next state
							reg_state_rx <= Suart_idle;
						end if;

					-- UART RX START_BIT STATE
					when Suart_start_bit =>
						-- Clock counter increment
						if reg_clk_count_rx /= to_integer(unsigned(reg_fbaud))-1 then
							reg_clk_count_rx <= reg_clk_count_rx + 1;
						else
							reg_clk_count_rx <= 0;
						end if;

						--  Next state
						if rx_sampling_s = '1' then
							reg_state_rx <= Suart_data_bits;
						else
							reg_state_rx <= Suart_start_bit;
						end if;

					-- UART RX DATA_BITS STATE
					when Suart_data_bits =>
						-- Clock counter increment
						if reg_clk_count_rx /= to_integer(unsigned(reg_fbaud))-1 then
							reg_clk_count_rx <= reg_clk_count_rx + 1;
						else
							reg_clk_count_rx <= 0;
						end if;

						-- Stop sampling if there are enought bits
						if reg_bit_count_rx = 8 then
							-- Next state
							reg_state_rx <= Suart_stop_bit;
						-- Sample baud at Rx with shift register
						elsif rx_sampling_s = '1' then
							reg_rx_data      <= uart_rx_i & reg_rx_data(7 downto 1);
							reg_bit_count_rx <= reg_bit_count_rx + 1;
							-- Next state
							reg_state_rx     <= Suart_data_bits;
						-- Wait for the moment to sample Rx
						else
							-- Next state
							reg_state_rx <= Suart_data_bits;
						end if;

					-- UART RX STOP_BIT STATE
					when Suart_stop_bit =>
						-- Clock counter increment
						if reg_clk_count_rx /= to_integer(unsigned(reg_fbaud))-1 then
							reg_clk_count_rx <= reg_clk_count_rx + 1;
						else
							reg_clk_count_rx <= 0;
						end if;

						-- Next state
						if reg_clk_count_rx = to_integer(unsigned(reg_fbaud)) - 1 then
							reg_state_rx <= Suart_idle;
						else
							reg_state_rx <= Suart_stop_bit;
						end if;

				end case;
			end if;
		end if;
	end process;

	-- -- UART Tx FSM
	-- UARTTX_FSM: process(clk)
	-- begin
		-- if rising_edge(clk) then
			-- if rstn = '0' then
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
	uart_data_rx_s(UART_DATA_WIDTH_c-1 downto 0)                <= reg_rx_data;
	uart_baud_s(APB_DATA_WIDTH_c-1 downto UART_FBAUD_WIDTH_c)    <= (others => '0');
	uart_baud_s(UART_FBAUD_WIDTH_c-1 downto 0)                   <= reg_fbaud;
	
	prdata_o  <= uart_data_rx_s when reg_state_apb = Sapb_setup and pwrite_i = '0' and reg_paddr = UART_DATA_ADDR_c else
	             uart_baud_s when reg_state_apb = Sapb_setup and pwrite_i = '0' and reg_paddr = UART_BAUD_ADDR_c else
	             (others => '0');
  
	-- Peripherals with fixed 2-cycle access can tie PREADY high
	pready_o <= '1';
	
	-- 
	address_exists_s <= '1' when reg_state_apb = Sapb_setup and (reg_paddr = UART_BAUD_ADDR_c or reg_paddr = UART_DATA_ADDR_c) else '0';
	pslverr_o        <= '1' when reg_state_apb = Sapb_setup and address_exists_s = '0' else '0';
	
	-- Drive UART
	-- UART Tx
	uart_tx_o <= '0';
	
	-- Interrupts
	-- 0: Rx interrupt is set during a single cycle, indicating that there is a byte available at Rx
	-- 1: Tx interrupt is always clear.
	int_o(0) <= rx_sampling_s when reg_state_rx = Suart_stop_bit else '0';
	int_o(1) <= '0'; 

end behavioral;