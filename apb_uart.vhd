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
		-- Bus widths
		APB_DATA_WIDTH   : natural range 0 to 32 := APB_DATA_WIDTH_c;     -- Width of the APB data bus
		APB_ADDR_WIDTH   : natural range 0 to 32 := APB_ADDR_WIDTH_c;     -- Width of the address bus
		-- Memory-mapped registers
		-- Register widths
		UART_DATA_WIDTH  : natural range 0 to 32 := UART_DATA_WIDTH_c;    -- Width of the UART words
		UART_CTRL_WIDTH  : natural range 0 to 32 := UART_CTRL_WIDTH_c;    -- Width of the FBAUD register
		UART_FBAUD_WIDTH : natural range 0 to 32 := UART_FBAUD_WIDTH_c;   -- Width of the FBAUD register
		-- Register addresses
		UART_DATA_ADDR   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0)  := UART_DATA_ADDR_c;
		UART_CTRL_ADDR   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0)  := UART_CTRL_ADDR_c;
		UART_BAUD_ADDR   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0)  := UART_BAUD_ADDR_c;
		-- Register reset values
		UART_FBAUD_RSTVL : std_logic_vector(UART_FBAUD_WIDTH_c-1 downto 0)  := UART_FBAUD_SIM_c;
		UART_CTRL_RSTVL  : std_logic_vector(UART_CTRL_WIDTH_c-1 downto 0) := UART_CTRL_RSTVL_c
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
	-- 0x04 - UART control register (1 bit)
	---- [0] - Stop bit: LOW for one, high for TWO stop bits
	-- 0x08 - UART frequency/baud ratio register: threshold for clock counter (16 bits, configurable) - floor(clk_freq/baud_rate)
	-- 0x0C (future) UART status register
	signal reg_data_tx    : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal reg_data_rx    : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal reg_control    : std_logic_vector(UART_CTRL_WIDTH-1 downto 0);
	signal reg_fbaud      : std_logic_vector(UART_FBAUD_WIDTH-1 downto 0);
	-- Associated signals
	signal uart_data_rx_s   : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal uart_baud_s      : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
	-- Control register outline
	signal uart_ctrl_stop_s : std_logic;
	
	-- UART
	-- Tx and Rx finite state machines
	type fsm_state_uart_t is (Suart_idle, Suart_start_bit, Suart_data_bits, Suart_stop_bit);
	signal reg_state_tx   : fsm_state_uart_t;
	signal reg_state_rx   : fsm_state_uart_t;
	
	-- Clock counters for baud generation
	signal reg_clk_count_tx : integer range 0 to 2**(UART_FBAUD_WIDTH + 1) - 1;
	signal reg_clk_count_rx : integer range 0 to 2**(UART_FBAUD_WIDTH + 1) - 1;
	
	-- Shift shift registers which drive reg_data_tx and reg_data_rx
	signal reg_shift_tx : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal reg_shift_rx : std_logic_vector(UART_DATA_WIDTH-1 downto 0);

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
				-- Memory-mapped registers driven by APB
				reg_data_tx <= (others => '0');
				reg_control <= UART_CTRL_RSTVL;
				reg_fbaud   <= UART_FBAUD_RSTVL;
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
							-- Next state
							reg_state_apb <= Sapb_setup;
						else
							-- Next state
							reg_state_apb <= Sapb_idle;
						end if;

					-- APB3 SETUP STATE
					when Sapb_setup =>
					
						-- APB writes to memory-mapped registers
						-- UART data Tx register
						if (penable_i and pwrite_i) = '1' and paddr_i = UART_DATA_ADDR then
							reg_data_tx <= pwdata_i(UART_DATA_WIDTH-1 downto 0);
						-- UART control register
						elsif (penable_i and pwrite_i) = '1' and paddr_i = UART_CTRL_ADDR then
							reg_control <= pwdata_i(UART_CTRL_WIDTH-1 downto 0);
						-- UART frequency/baud ratio register
						elsif (penable_i and pwrite_i) = '1' and paddr_i = UART_BAUD_ADDR then
							reg_fbaud <= pwdata_i(UART_FBAUD_WIDTH-1 downto 0);
						end if;
							
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
	-- Samples the Rx signal;
	-- FUTURE: sample multiple times and do a voting
	rx_sampling_s <= '1' when reg_clk_count_rx = to_integer(unsigned(reg_fbaud))/2 else '0';

	UARTRX_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- Memory-mapped register driven by UART Rx (read-only from APB)
				reg_data_rx <= (others => '0');
				-- UART Rx registers
				reg_shift_rx <= (others => '0');
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
						
						-- Next state
						if uart_rx_i = '0' then
							reg_state_rx <= Suart_start_bit;
						else
							reg_state_rx <= Suart_idle;
						end if;

					-- UART RX START_BIT STATE
					when Suart_start_bit =>
						-- Clock counter increment
						if reg_clk_count_rx /= to_integer(unsigned(reg_fbaud)) - 1 then
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
						if reg_clk_count_rx /= to_integer(unsigned(reg_fbaud)) - 1 then
							reg_clk_count_rx <= reg_clk_count_rx + 1;
						else
							reg_clk_count_rx <= 0;
						end if;

						-- Sample baud at Rx with shift register
						if rx_sampling_s = '1' then
							-- 
							reg_shift_rx <= uart_rx_i & reg_shift_rx(7 downto 1);
							reg_bit_count_rx <= reg_bit_count_rx + 1;
							-- Next state
							reg_state_rx <= Suart_data_bits;
						end if;
						
						-- Stop sampling if there are enought bits						
						if reg_bit_count_rx = 8 then
							reg_data_rx <= reg_shift_rx;
							-- Next state
							reg_state_rx <= Suart_stop_bit;
						else
							-- Next state
							reg_state_rx <= Suart_data_bits;
						end if;

					-- UART RX STOP_BIT STATE
					when Suart_stop_bit =>
						-- Clock counter increment
						if reg_clk_count_rx /= to_integer(unsigned(reg_fbaud)) - 1 then
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

	-- UART Tx FSM
	UARTTX_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- UART Tx registers
				reg_shift_tx <= (others => '0');
				reg_clk_count_tx <= 0;
				reg_bit_count_tx <= 0;
				-- FSM state register
				reg_state_tx <= Suart_idle;
			else
				case reg_state_tx is

					-- UART TX IDLE STATE
					when Suart_idle =>
						-- Clock and bit counters reset
						reg_clk_count_tx <= 0;
						reg_bit_count_tx <= 0;
						
						-- UART Tx start depends on the APB frontend
						if (penable_i and psel_i and pwrite_i) = '1' and paddr_i = UART_DATA_ADDR then
							reg_state_tx <= Suart_start_bit;
						else 
							reg_state_tx <= Suart_idle;
						end if;

					-- UART TX START_BIT STATE
					when Suart_start_bit =>
						-- Clock counter increment and reset
						if reg_clk_count_tx = to_integer(unsigned(reg_fbaud)) - 1 then
							-- Copy Tx data to shift register 
							reg_shift_tx <= reg_data_tx;
							-- Next state
							reg_state_tx <= Suart_data_bits;
							reg_clk_count_tx <= 0;
						else
							-- Next state
							reg_state_tx <= Suart_start_bit;
							reg_clk_count_tx <= reg_clk_count_tx + 1;
						end if;

					-- UART TX DATA_BITS STATE
					when Suart_data_bits =>
						-- Clock counter increment and reset
						if reg_clk_count_tx = to_integer(unsigned(reg_fbaud)) - 1 then
							-- Shift Tx register
							reg_shift_tx <= '0' & reg_shift_tx(UART_DATA_WIDTH-1 downto 1);
							-- Bit counter increment
							reg_bit_count_tx <= reg_bit_count_tx + 1;
							reg_clk_count_tx <= 0;
						else
							reg_clk_count_tx <= reg_clk_count_tx + 1;
						end if;

						-- Stop sampling if there are enought bits
						if reg_bit_count_tx = 8 then
							-- Next state
							reg_state_tx <= Suart_stop_bit;
						else 
							-- Next state
							reg_state_tx <= Suart_data_bits;
						end if;

					-- UART TX STOP_BIT STATE
					when Suart_stop_bit =>
						-- 1 stop bit
						if uart_ctrl_stop_s = '0' then
							-- Clock counter increment and reset
							if reg_clk_count_tx = to_integer(unsigned(reg_fbaud)) - 1 then
								-- Next state
								reg_state_tx <= Suart_idle;
								reg_clk_count_tx <= 0;
							else
								-- Next state
								reg_state_tx <= Suart_stop_bit;
								reg_clk_count_tx <= reg_clk_count_tx + 1;
							end if;
						
						-- 2 stop bits
						else 
							-- Clock counter increment and reset
							if reg_clk_count_tx = (2 * to_integer(unsigned(reg_fbaud))) - 1 then
								-- Next state
								reg_state_tx <= Suart_idle;
								reg_clk_count_tx <= 0;
							else
								-- Next state
								reg_state_tx <= Suart_stop_bit;
								reg_clk_count_tx <= reg_clk_count_tx + 1;
							end if;
						
						end if;
						

						
				end case;
			end if;
		end if;
	end process;

	-- Control register signals
	uart_ctrl_stop_s    <= reg_control(0);	

	-- Drive APB outputs
	-- Assembly APB-width signals
	uart_data_rx_s(APB_DATA_WIDTH-1 downto UART_DATA_WIDTH_c) <= (others => '0');
	uart_data_rx_s(UART_DATA_WIDTH-1 downto 0)                <= reg_data_rx;
	uart_baud_s(APB_DATA_WIDTH-1 downto UART_FBAUD_WIDTH_c)   <= (others => '0');
	uart_baud_s(UART_FBAUD_WIDTH-1 downto 0)                  <= reg_fbaud;
	
	prdata_o  <= uart_data_rx_s when reg_state_apb = Sapb_setup and pwrite_i = '0' and reg_paddr = UART_DATA_ADDR else
	             uart_baud_s    when reg_state_apb = Sapb_setup and pwrite_i = '0' and reg_paddr = UART_BAUD_ADDR else
	             (others => '0');
  
	-- Peripherals with fixed 2-cycle access can tie PREADY high
	pready_o <= '1';
	
	-- 
	address_exists_s <= '1' when reg_state_apb = Sapb_setup and (reg_paddr = UART_BAUD_ADDR or 
	                                                             reg_paddr = UART_DATA_ADDR) else '0';
	pslverr_o        <= '1' when reg_state_apb = Sapb_setup and address_exists_s = '0' else '0';
	
	-- Drive UART
	-- UART Tx
	uart_tx_o <= '0' when reg_state_tx = Suart_start_bit else                 -- Start bit
	             reg_shift_tx(0) when reg_state_tx = Suart_data_bits else     -- Data bits
							 '1';                                                         -- Stop bit
	
	-- Interrupts
	-- 0: Rx interrupt is set during a single cycle, indicating that there is a byte available at Rx
	-- 1: Tx interrupt is set during a single cycle, indicating the end of a transmission.
	int_o(0) <= rx_sampling_s when reg_state_rx = Suart_stop_bit else '0';
	int_o(1) <= '1' when (reg_state_tx = Suart_stop_bit and uart_ctrl_stop_s = '0' and reg_clk_count_tx = to_integer(unsigned(reg_fbaud)) - 1) or
                       (reg_state_tx = Suart_stop_bit and uart_ctrl_stop_s = '1' and reg_clk_count_tx = (2 * to_integer(unsigned(reg_fbaud))) - 1) else
							'0'; 

end behavioral;