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
	use ieee.numeric_std.all;
	use ieee.std_logic_1164.all;

--
	use work.pkg_apbuart.all;

entity apb_uart is
	generic (
		-- Bus widths
		APB_DATA_WIDTH    : natural range 8 to 32 := APB_DATA_WIDTH_c;
		APB_ADDR_WIDTH    : natural range 8 to 32 := APB_ADDR_WIDTH_c;
		-- UART Tx and Rx FIFOs
		UART_FIFO_SIZE_E  : natural range 0 to 10 := UART_FIFO_SIZE_E_c;                                -- UART FIFOs size = 2^FIFO_SIZE_E
		FIFO_EDAC_WIDTH   : natural range 0 to 16 := FIFO_EDAC_WIDTH_EN_c;
		FIFO_ENABLE_EDAC  : std_logic             := FIFO_ENABLE_EDAC_c;
		-- Memory-mapped registers
		-- Register widths
		UART_DATA_WIDTH   : natural range 8 to 8  := UART_DATA_WIDTH_c;
		UART_FBAUD_WIDTH  : natural range 0 to 32 := UART_FBAUD_WIDTH_c;
		UART_CTRL_WIDTH   : natural range 0 to 32 := UART_CTRL_WIDTH_c;
		UART_NUM_INT      : natural range 0 to 8  := UART_NUM_INT_c;
		-- Register addresses
		UART_DATA_ADDR    : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := UART_DATA_ADDR_c;
		UART_FBAUD_ADDR   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := UART_FBAUD_ADDR_c;
		UART_CTRL_ADDR    : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := UART_CTRL_ADDR_c;
		UART_INTEN_ADDR   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := UART_INTEN_ADDR_c;
		UART_INTPEND_ADDR : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := UART_INTPEND_ADDR_c;
		-- Register reset values
		-- Data and interrupt pending registers do not have configurable reset values
		UART_FBAUD_RSTVL  : integer range 0 to 2**UART_FBAUD_WIDTH_c-1     := UART_FBAUD_SIM_c;
		UART_CTRL_RSTVL   : std_logic_vector(UART_CTRL_WIDTH_c-1 downto 0) := UART_CTRL_RSTVL_c;
		UART_INTEN_RSTVL  : std_logic_vector(UART_NUM_INT_c-1 downto 0)    := INT_RX_FIFO_EMPTY_c
	);
	port(
		-- Clock and reset (active low)
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
		rx_i      : in std_logic;
		tx_o      : out std_logic;
		-- Interrupt
		int_o     : out std_logic
	);
end apb_uart;

architecture behavioral of apb_uart is
	-- AMBA APB
	-- APB finite state machine
	type fsm_state_apb_t is(Sapb_idle, Sapb_setup, Sapb_access);
	signal reg_state_apb : fsm_state_apb_t;

	-- APB registers
	signal reg_paddr   : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
	signal reg_pwrite  : std_logic;
	signal reg_penable : std_logic;
	signal valid_address_s : std_logic;
	
	-- Memory-mapped registers 
	signal reg_data_tx : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal reg_fbaud   : integer range 0 to 2**UART_FBAUD_WIDTH - 1;
	signal reg_control : std_logic_vector(UART_CTRL_WIDTH-1 downto 0);
	signal reg_inten   : std_logic_vector(UART_NUM_INT-1 downto 0);
	signal reg_intpend : std_logic_vector(UART_NUM_INT-1 downto 0);
	signal intpend_s   : std_logic_vector(UART_NUM_INT-1 downto 0);
	
	-- Control register outline
	signal ctrl_stop_s        : std_logic;                        -- [0] Stop bit: LOW for one, high for TWO stop bits
	signal ctrl_parity_en_s   : std_logic;                        -- [1] Parity enable
	signal ctrl_parity_type_s : std_logic;                        -- [2] Parity select: LOW for odd, HIGH for even
	signal ctrl_txfifo_wm_s   : unsigned(7 downto 0);             -- [3-10] (future) Tx FIFO watermark size_e: watermark = 2^(size_e)
	signal ctrl_rxfifo_wm_s   : unsigned(7 downto 0);             -- [11-18] (future) Rx FIFO watermark size_e: watermark = 2^(size_e)
	
	-- Interrupt enable register outline
	signal inten_txfifo_full_s  : std_logic;                      -- [0] Tx FIFO full
	signal inten_rxfifo_full_s  : std_logic;                      -- [1] Rx FIFO full
	signal inten_txfifo_empty_s : std_logic;                      -- [2] Tx FIFO empty
	signal inten_rxfifo_empty_s : std_logic;                      -- [3] Rx FIFO empty
	signal inten_txfifo_wm_s    : std_logic;                      -- [4] Tx FIFO positions occupied < watermark
	signal inten_rxfifo_wm_s    : std_logic;                      -- [5] Rx FIFO positions occupied > watermark
		
	-- Interrupt output outline
	signal int_txfifo_wm_s    : std_logic;                        -- [4] Tx FIFO positions occupied < watermark
	signal int_rxfifo_wm_s    : std_logic;                        -- [5] Rx FIFO positions occupied > watermark
	
	-- Expand UART registers to APB data bus width
	signal expand_rxword_s  : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal expand_fbaud_s   : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal expand_control_s : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal expand_inten_s   : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal expand_intpend_s : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	
	-- UART	
	-- Tx and Rx finite state machines
	type fsm_state_uart_t is (Suart_idle, Suart_start_bit, Suart_data_bits, Suart_parity_bit, Suart_stop_bit);
	signal reg_state_tx : fsm_state_uart_t;
	signal reg_state_rx : fsm_state_uart_t;
	
	-- Tx FIFO
	signal txfifo_push_s  : std_logic;
	signal txfifo_pop_s   : std_logic;
	signal txfifo_in_s    : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal txfifo_out_s   : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal txfifo_full_s  : std_logic;
	signal txfifo_empty_s : std_logic;
	signal txfifo_usage_s : std_logic_vector(UART_FIFO_SIZE_E downto 0);
	
	-- Rx FIFO
	signal rxfifo_push_s  : std_logic;
	signal rxfifo_pop_s   : std_logic;
	signal rxfifo_in_s    : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal rxfifo_out_s   : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal rxfifo_full_s  : std_logic;
	signal rxfifo_empty_s : std_logic;
	signal rxfifo_usage_s : std_logic_vector(UART_FIFO_SIZE_E downto 0);
	
	-- Clock counters to measure the duration of UART bauds (the max. value it must keep is 2*max_FBaud)
	signal reg_clk_count_tx    : integer range 0 to 2**(UART_FBAUD_WIDTH + 1) - 1;
	signal reg_clk_count_rx    : integer range 0 to 2**(UART_FBAUD_WIDTH + 1) - 1;
	signal tx_counting_clock_s : std_logic;
	signal rx_counting_clock_s : std_logic;
	
	-- Shift registers for UART TX and Rx
	signal reg_shift_tx : std_logic_vector(UART_DATA_WIDTH-1 downto 0);
	signal reg_shift_rx : std_logic_vector(UART_DATA_WIDTH-1 downto 0);

	-- Bit counters for data transmission and reception
	signal reg_bit_count_tx : integer range 0 to 8;
	signal reg_bit_count_rx : integer range 0 to 8;
	
	-- UART Rx sampling is preceded by a metastability filter that is always enabled
	-- The filter feeds a 3-bit shift register which samples rx_i at 8x the baud rate
	-- Before feeding the UART Rx logic, the 3-bit shift register feeds a majority voter
	signal reg_mfilter_rx : std_logic_vector(1 downto 0);              -- 2-FF metastability filter
	signal reg_shift_mv   : std_logic_vector(2 downto 0);              -- 3-bit shift register with Fs=8xBaudRate
	signal mv_out_s       : std_logic;                                 -- Majority voter of the 3-bit shift register
	
	-- Clock counter to enable sampling the from the 2-stage metastability filter
	-- to the 3-bit voter at Fs = floor(baud_rate/8)
	signal reg_clk_count_fs : integer range 0 to 2**UART_FBAUD_WIDTH - 1;
	-- Indicator of the rx sampling moment from s.r. to FIFO
	signal rx_sampling_s  : std_logic;                                 

	-- Parity bit holders
	signal reg_parity_tx          : std_logic;
	signal reg_parity_rx_computed : std_logic;
	signal reg_parity_rx_read     : std_logic;
	
	-- Outputs
	signal prdata_s  : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	signal pready_s  : std_logic;
	signal pslverr_s : std_logic;
	signal tx_s      : std_logic;
	signal int_s     : std_logic;
	
begin

	-- AMBA 3 APB
	-- APB FSM
	APB_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				reg_paddr <= (others => '0');
				reg_pwrite <= '0';
				reg_penable <= '0';
				-- Memory-mapped registers driven by APB
				reg_data_tx <= (others => '0');
				reg_fbaud   <= UART_FBAUD_RSTVL;
				reg_control <= UART_CTRL_RSTVL;
				reg_inten   <= UART_INTEN_RSTVL;
				reg_intpend <= (others => '0');
				-- State register
				reg_state_apb <= Sapb_idle;
			else
				case reg_state_apb is
				-- APB3 IDLE STATE
					when Sapb_idle =>
						-- Wait for APB peripheral selection
						if psel_i = '1' then
							-- Keep address and reg. operation
						  reg_paddr <= paddr_i;
							reg_pwrite <= pwrite_i;
							-- Update interrupt pending register
							reg_intpend <= intpend_s;
							
							-- Write to memory-mapped registers
							if pwrite_i = '1' then
								-- UART data Tx register
								if paddr_i = UART_DATA_ADDR then
									reg_data_tx <= pwdata_i(UART_DATA_WIDTH-1 downto 0);
									-- UART frequency/baud ratio register	
								elsif paddr_i = UART_FBAUD_ADDR then
									reg_fbaud <= to_integer(unsigned(pwdata_i(UART_FBAUD_WIDTH-1 downto 0)));
								-- UART control register
								elsif paddr_i = UART_CTRL_ADDR then
									reg_control <= pwdata_i(UART_CTRL_WIDTH-1 downto 0);
								-- UART interrupt enable register
								elsif paddr_i = UART_INTEN_ADDR then
									reg_inten <= pwdata_i(UART_NUM_INT-1 downto 0);
								end if;
							end if;
							
							reg_state_apb <= Sapb_setup;
						else
							reg_state_apb <= Sapb_idle;
						end if;

					-- APB3 SETUP STATE
					when Sapb_setup =>
						-- Keep enable value
						reg_penable <= penable_i;
					  -- 
						reg_state_apb <= Sapb_access;

					-- APB3 ACCESS STATE
					when Sapb_access =>
						reg_state_apb <= Sapb_idle;

				end case;
			end if;
		end if;
	end process;

	-- UART
	-- FIFO interrupts
	-- Watermark interrupt conditions
	int_txfifo_wm_s <= '1' when unsigned(txfifo_usage_s) < ctrl_txfifo_wm_s else '0';
	int_rxfifo_wm_s <= '1' when unsigned(rxfifo_usage_s) > ctrl_rxfifo_wm_s else '0';
	-- Assign each bit to interrupt 
	intpend_s(0) <= '1' when (inten_txfifo_full_s and txfifo_full_s) = '1' else '0';              -- [0] Tx FIFO full
	intpend_s(1) <= '1' when (inten_rxfifo_full_s and rxfifo_full_s) = '1' else '0';              -- [1] Rx FIFO full
	intpend_s(2) <= '1' when (inten_txfifo_empty_s and txfifo_empty_s) = '1' else '0';            -- [2] Tx FIFO empty
	intpend_s(3) <= '1' when (inten_rxfifo_empty_s and rxfifo_empty_s) = '1' else '0';            -- [3] Rx FIFO empty
	intpend_s(4) <= '1' when (inten_txfifo_wm_s and int_txfifo_wm_s) = '1' else '0';              -- [4] Tx FIFO positions occupied < watermark
	intpend_s(5) <= '1' when (inten_rxfifo_wm_s and int_rxfifo_wm_s) = '1' else '0';              -- [5] Rx FIFO positions occupied > watermark
	
	-- Discrimination of signals
	-- Memory-mapped UART control register
	ctrl_stop_s        <= reg_control(0);	
	ctrl_parity_en_s   <= reg_control(1);
	ctrl_parity_type_s <= reg_control(2);
	ctrl_txfifo_wm_s   <= unsigned(reg_control(10 downto 3));
	ctrl_rxfifo_wm_s   <= unsigned(reg_control(18 downto 11));
	-- Interrupt enable register outline
	inten_txfifo_full_s  <= reg_inten(0);                                                         -- [0] Tx FIFO full
	inten_rxfifo_full_s  <= reg_inten(1);                                                         -- [1] Rx FIFO full
	inten_txfifo_empty_s <= reg_inten(2);                                                         -- [2] Tx FIFO empty
	inten_rxfifo_empty_s <= reg_inten(3);                                                         -- [3] Rx FIFO empty
	inten_txfifo_wm_s    <= reg_inten(4);                                                         -- [4] Tx FIFO positions occupied < watermark
	inten_rxfifo_wm_s    <= reg_inten(5);                                                         -- [5] Rx FIFO positions occupied > watermark
	
	-- UART Tx FIFO
	txfifo_pop_s  <= '1' when reg_state_tx = Suart_start_bit and tx_counting_clock_s = '0' else '0';            -- Pops from Tx FIFO after the FIFO feeds the Tx shift register
	txfifo_in_s   <= reg_data_tx;                                                                               --	Tx FIFO reads data from the memory-mapped Tx data register
	txfifo_push_s <= '1' when reg_state_apb = Sapb_access and reg_pwrite = '1' and reg_paddr = UART_DATA_ADDR else '0';           -- Push to Tx FIFO in APB writes to UART_DATA_ADDR
	
	TX_FIFO: entity work.dp_fifo(behavioral)
	generic map(
		FIFO_SIZE_E => UART_FIFO_SIZE_E,
		FIFO_WIDTH  => UART_DATA_WIDTH,
		EDAC_WIDTH  => FIFO_EDAC_WIDTH,
		ENABLE_EDAC => FIFO_ENABLE_EDAC
	)
	port map(
		clk     => clk,
		rstn    => rstn,
		push_i  => txfifo_push_s,
		data_i  => txfifo_in_s,
		pop_i   => txfifo_pop_s,
		data_o  => txfifo_out_s,
		full_o  => txfifo_full_s,
		empty_o => txfifo_empty_s,
		usage_o => txfifo_usage_s
	);
	
	-- UART Rx FIFO
	rxfifo_pop_s <= '1' when reg_state_apb = Sapb_setup and reg_pwrite = '0' and reg_paddr = UART_DATA_ADDR else '0';                 -- Pop from Rx FIFO in APB reads from UART_DATA_ADDR
	rxfifo_in_s  <= reg_shift_rx;                                                                                                   -- Rx FIFO reads from the DATA_WIDTH-bits shift register
	-- Push to Rx FIFO either on the last data baud or after parity checking
	rxfifo_push_s <= '1' when (ctrl_parity_en_s = '0' and reg_state_rx = Suart_data_bits and rx_counting_clock_s = '0' and reg_bit_count_rx = UART_DATA_WIDTH) or          -- For parity disabled
														(reg_state_rx = Suart_parity_bit and rx_counting_clock_s = '0' and reg_parity_rx_read = reg_parity_rx_computed) else '0';                    -- For parity enabled
	
	RX_FIFO: entity work.dp_fifo(behavioral)
	generic map(
		FIFO_SIZE_E => UART_FIFO_SIZE_E,
		FIFO_WIDTH  => UART_DATA_WIDTH,
		EDAC_WIDTH  => FIFO_EDAC_WIDTH,
		ENABLE_EDAC => FIFO_ENABLE_EDAC
	)
	port map(
		clk     => clk,
		rstn    => rstn,
		push_i  => rxfifo_push_s,
		data_i  => rxfifo_in_s,
		pop_i   => rxfifo_pop_s,
		data_o  => rxfifo_out_s,
		full_o  => rxfifo_full_s,
		empty_o => rxfifo_empty_s,
		usage_o => rxfifo_usage_s
	);
	
	-- UART Tx FSM
	-- Active while baud period has not finished
	tx_counting_clock_s <= '1' when reg_clk_count_tx /= reg_fbaud - 1 else '0';
	
	UARTTX_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- UART Tx registers
				reg_shift_tx <= (others => '0');
				reg_clk_count_tx <= 0;
				reg_bit_count_tx <= 0;
				reg_parity_tx <= '0';   
				-- FSM state register
				reg_state_tx <= Suart_idle;
			else
				case reg_state_tx is

					-- UART TX IDLE STATE
					when Suart_idle =>
						-- Clock and bit counters reset
						reg_clk_count_tx <= 0;
						reg_bit_count_tx <= 0;
						
						-- Transmit data whenever the Tx FIFO is not empty
						-- if (penable_i and psel_i and pwrite_i) = '1' and paddr_i = UART_DATA_ADDR then
						if txfifo_empty_s = '0' then
							reg_state_tx <= Suart_start_bit;
						else 
							reg_state_tx <= Suart_idle;
						end if;

					-- UART TX START_BIT STATE
					when Suart_start_bit =>
						-- Clock counter increment and reset
						-- Count up to (1/baud_rate) s
						if tx_counting_clock_s = '1' then
							reg_state_tx <= Suart_start_bit;
							reg_clk_count_tx <= reg_clk_count_tx + 1;
						else 
							reg_state_tx <= Suart_data_bits;
							reg_clk_count_tx <= 0;
							-- Copy Tx data to shift register
							reg_shift_tx <= txfifo_out_s;
							-- If enabled, the parity type control bit determines
							-- the initial value for the parity bit
							if ctrl_parity_en_s = '1' then 
								reg_parity_tx <= ctrl_parity_type_s;
							end if;
						end if;

					-- UART TX DATA_BITS STATE
					when Suart_data_bits =>
						-- Clock counter increment and reset
						-- Count up to (1/baud_rate) s
						if tx_counting_clock_s = '1' then
							reg_clk_count_tx <= reg_clk_count_tx + 1;
						else
							-- Update parity bit
							if ctrl_parity_en_s = '1' then
								reg_parity_tx <= reg_parity_tx xor reg_shift_tx(0);
							end if;
							-- Bit counter increment
							reg_bit_count_tx <= reg_bit_count_tx + 1;
							reg_clk_count_tx <= 0;
							
							-- Update Tx shift register
							-- Only update sr if next state is still data bits, else we may get a glitch of one-cycle LOW TX from HIGH data bit to HIGH stop bit
							if reg_bit_count_tx /= UART_DATA_WIDTH-1 then
								reg_shift_tx <= '0' & reg_shift_tx(UART_DATA_WIDTH-1 downto 1);
							end if;
						end if;

						-- Stop tx shift register after UART_DATA_WIDTH-1 bits and
						-- account for the parity enable/disable config. register bit
						if ctrl_parity_en_s = '0' and (reg_bit_count_tx = UART_DATA_WIDTH) then
							reg_state_tx <= Suart_stop_bit;
						elsif ctrl_parity_en_s = '1' and (reg_bit_count_tx = UART_DATA_WIDTH) then
							reg_state_tx <= Suart_parity_bit;
						else 
							reg_state_tx <= Suart_data_bits;
						end if;
						
					-- UART TX PARITY BIT STATE
					when Suart_parity_bit =>
						-- Clock counter increment and reset
						if tx_counting_clock_s = '1' then
							reg_state_tx <= Suart_parity_bit;
							reg_clk_count_tx <= reg_clk_count_tx + 1;
						else
							reg_state_tx <= Suart_stop_bit;
							reg_clk_count_tx <= 0;
						end if;
					
					-- UART TX STOP_BIT STATE
					when Suart_stop_bit =>
						-- 1 stop bit
						if ctrl_stop_s = '0' then
							-- Clock counter increment and reset
							-- Count up to (1/baud_rate) s
							if tx_counting_clock_s = '1' then
								reg_state_tx <= Suart_stop_bit;
								reg_clk_count_tx <= reg_clk_count_tx + 1;
							else
								reg_state_tx <= Suart_idle;
								reg_clk_count_tx <= 0;
							end if;
						
						-- 2 stop bits
						else 
							-- Clock counter increment and reset
							-- Count up to 2*(1/baud_rate)
							if reg_clk_count_tx = (2 * reg_fbaud) - 1 then
								reg_state_tx <= Suart_idle;
								reg_clk_count_tx <= 0;
							else
								reg_state_tx <= Suart_stop_bit;
								reg_clk_count_tx <= reg_clk_count_tx + 1;
							end if;
						end if;
						
				end case;
			end if;
		end if;
	end process;
	
	-- UART Rx FSM
	-- Indicate the moment to sample baud
	rx_sampling_s <= '1' when rstn = '1' and reg_clk_count_rx = reg_fbaud/2 else '0';
	-- Active while baud period has not finished
	rx_counting_clock_s <= '1' when reg_clk_count_rx /= reg_fbaud - 1 else '0';

	UARTRX_FSM: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- UART Rx registers
				reg_shift_rx <= (others => '0');
				reg_parity_rx_computed <= '0';
				reg_parity_rx_read <= '0';
				-- FSM state register
				reg_state_rx <= Suart_idle;
			else
				case reg_state_rx is

					-- UART RX IDLE STATE
					when Suart_idle =>
						-- 
						reg_clk_count_rx <= 0;
						reg_bit_count_rx <= 0;
						
						if mv_out_s = '0' then
							reg_state_rx <= Suart_start_bit;
						else
							reg_state_rx <= Suart_idle;
						end if;

					-- UART RX START_BIT STATE
					when Suart_start_bit =>
						-- Clock counter increment
						-- Count up to (1/baud_rate) s
						if rx_counting_clock_s = '1' then
							reg_clk_count_rx <= reg_clk_count_rx + 1;
							reg_state_rx <= Suart_start_bit;
						else
							reg_clk_count_rx <= 0;
							reg_state_rx <= Suart_data_bits;
							-- If enabled, the parity type control bit determines
							-- the initial value for the parity bit
							if ctrl_parity_en_s = '1' then 
								reg_parity_rx_computed <= ctrl_parity_type_s;
							end if;
						end if;

					-- UART RX DATA_BITS STATE
					when Suart_data_bits =>
						-- Sample baud from the 3-bit majority voter
						if rx_sampling_s = '1' then
							reg_shift_rx <= mv_out_s & reg_shift_rx(7 downto 1);
							reg_bit_count_rx <= reg_bit_count_rx + 1;
							-- Update parity
							if ctrl_parity_en_s = '1' then
								reg_parity_rx_computed <= reg_parity_rx_computed xor mv_out_s;
							end if;
						end if;
						
						-- Clock counter increment and reset
						-- Count up to (1/baud_rate) s
						if rx_counting_clock_s = '1' then
							reg_clk_count_rx <= reg_clk_count_rx + 1;										
						else
							reg_clk_count_rx <= 0;
							-- Only verify the number of bits received at the end of the baud period
							if reg_bit_count_rx = UART_DATA_WIDTH and ctrl_parity_en_s = '0' then
								reg_state_rx <= Suart_stop_bit;
							elsif reg_bit_count_rx = UART_DATA_WIDTH and ctrl_parity_en_s = '1' then
								reg_state_rx <= Suart_parity_bit;
							else
								reg_state_rx <= Suart_data_bits;
							end if;
						end if;
						
					-- UART RX PARITY BIT STATE
					when Suart_parity_bit =>
						-- Sample parity bit from the 3-bit majority voter
						if rx_sampling_s = '1' then
							reg_parity_rx_read <= mv_out_s;
						end if;
						
						-- Clock counter increment and reset
						-- Count up to (1/baud_rate) s
						if rx_counting_clock_s = '1' then
							reg_clk_count_rx <= reg_clk_count_rx + 1;
							reg_state_rx <= Suart_parity_bit;
						else
							reg_clk_count_rx <= 0;
							reg_state_rx <= Suart_stop_bit;
						end if;
					
					-- UART RX STOP_BIT STATE
					when Suart_stop_bit =>
						-- Clock counter increment and reset
						-- Count up to (1/baud_rate) s
						if rx_counting_clock_s = '1' then
							reg_clk_count_rx <= reg_clk_count_rx + 1;
							reg_state_rx <= Suart_stop_bit;
						else
							reg_clk_count_rx <= 0;
							reg_state_rx <= Suart_idle;
						end if;

				end case;
			end if;
		end if;
	end process;

	-- Rx sampling
	-- Majority voter from 3-bit sampling shift register
	mv_out_s <= (reg_shift_mv(0) and reg_shift_mv(1)) or 
							(reg_shift_mv(1) and reg_shift_mv(2)) or
							(reg_shift_mv(0) and reg_shift_mv(2));
	
	UARTRX_SAMPLER: process(clk)
	begin
		if rising_edge(clk) then
			if rstn = '0' then
				-- Metastability filter and voter shift register must start w/ all ones
				-- Else, UART Rx will get a spurious START BIT after rstn goes high
				reg_mfilter_rx <= (others => '1');
				reg_shift_mv <= (others => '1');
				reg_clk_count_fs <= 0;
			else
				-- Metastability filter shift register
				reg_mfilter_rx <= rx_i & reg_mfilter_rx(1);
				
				-- Sampling clock counter increment and reset
				-- Count up to 1/(8 * baud_rate) s
				if reg_clk_count_fs /= shift_right(to_unsigned(reg_fbaud, UART_FBAUD_WIDTH), 3) - 1 then
					reg_clk_count_fs <= reg_clk_count_fs + 1;
				else
					reg_shift_mv <= reg_mfilter_rx(0) & reg_shift_mv(2 downto 1);
					reg_clk_count_fs <= 0;
				end if;
			end if;
		end if;
	end process;

	-- Drive APB outputs
	-- Assembly APB-width signals
	expand_rxword_s(APB_DATA_WIDTH-1 downto UART_DATA_WIDTH)  <= (others => '0');
	expand_rxword_s(UART_DATA_WIDTH-1 downto 0)               <= rxfifo_out_s;
	expand_fbaud_s(APB_DATA_WIDTH-1 downto UART_FBAUD_WIDTH)  <= (others => '0');
	expand_fbaud_s(UART_FBAUD_WIDTH-1 downto 0)               <= std_logic_vector(to_unsigned(reg_fbaud, UART_FBAUD_WIDTH));
	expand_control_s(APB_DATA_WIDTH-1 downto UART_CTRL_WIDTH) <= (others => '0');
	expand_control_s(UART_CTRL_WIDTH-1 downto 0)              <= reg_control;
	expand_inten_s(APB_DATA_WIDTH-1 downto UART_NUM_INT)    <= (others => '0');
	expand_inten_s(UART_NUM_INT-1 downto 0)                 <= reg_inten;
	expand_intpend_s(APB_DATA_WIDTH-1 downto UART_NUM_INT)  <= (others => '0');
	expand_intpend_s(UART_NUM_INT-1 downto 0)               <= reg_intpend;
	-- Read data bus
	prdata_s  <= expand_rxword_s  when reg_state_apb = Sapb_setup and reg_pwrite = '0' and reg_paddr = UART_DATA_ADDR else
	             expand_fbaud_s   when reg_state_apb = Sapb_setup and reg_pwrite = '0' and reg_paddr = UART_FBAUD_ADDR else
	             expand_control_s when reg_state_apb = Sapb_setup and reg_pwrite = '0' and reg_paddr = UART_CTRL_ADDR else
	             expand_inten_s   when reg_state_apb = Sapb_setup and reg_pwrite = '0' and reg_paddr = UART_INTEN_ADDR else
	             expand_intpend_s when reg_state_apb = Sapb_setup and reg_pwrite = '0' and reg_paddr = UART_INTPEND_ADDR else
	             (others => '0');
  
	-- Address validity
	valid_address_s <= '1' when reg_state_apb = Sapb_setup and ((reg_pwrite = '0' and (reg_paddr = UART_FBAUD_ADDR or reg_paddr = UART_DATA_ADDR or reg_paddr = UART_CTRL_ADDR or reg_paddr = UART_INTEN_ADDR or reg_paddr = UART_INTPEND_ADDR))
	                                                         or (reg_pwrite = '1' and (reg_paddr = UART_FBAUD_ADDR or reg_paddr = UART_DATA_ADDR or reg_paddr = UART_CTRL_ADDR or reg_paddr = UART_INTEN_ADDR))) else '0'; 
	pslverr_s       <= '1' when reg_state_apb = Sapb_setup and valid_address_s = '0' else '0';

	-- UART Tx
	tx_s <= '0' when reg_state_tx = Suart_start_bit else                                           -- Start bit
	        reg_shift_tx(0) when reg_state_tx = Suart_data_bits else                               -- Data bits
					reg_parity_tx when reg_state_tx = Suart_parity_bit else                                -- Parity bit (optional: none, odd, even)
					'1';                                                                                   -- Stop bit (optional: 1, 2)
					
	-- Interrupt
	int_s <= '1' when unsigned(intpend_s) /= 0 else '0';
	
	-- Drive outputs
	prdata_o  <= prdata_s;
	pready_o  <= '1';                       	-- Peripherals with fixed 2-cycle access can tie PREADY high
	pslverr_o <= pslverr_s;
	tx_o      <= tx_s;
	int_o     <= int_s;
	
	-- Hardware flow control
	-- -- rx outputs rst HIGH when the rx FIFO has RX_WATERMARK or less words in memory
	-- rts_o <= not int_rxfifo_wm_s;
	

end behavioral;