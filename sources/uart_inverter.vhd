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
	use work.pkg_apbuart.all;

entity uart_inverter is
	generic (
		-- Bus widths
		APB_DATA_WIDTH    : natural range 8 to 32 := APB_DATA_WIDTH_c;
		APB_ADDR_WIDTH    : natural range 8 to 32 := APB_ADDR_WIDTH_c;
		-- UART Tx and Rx FIFOs
		UART_FIFO_SIZE_E  : natural range 0 to 10 := UART_FIFO_SIZE_E_c;                                -- UART FIFOs size = 2^FIFO_SIZE_E
		FIFO_EDAC_WIDTH   : natural range 0 to 16 := FIFO_EDAC_WIDTH_EN_c;
		FIFO_ENABLE_EDAC  : std_logic             := FIFO_ENABLE_EDAC_c;
		-- Memory-mapped registers reset values
		UART_FBAUD_RSTVL : natural range 0 to 2**UART_FBAUD_WIDTH_c-1 := UART_FBAUD_SIM_c;
		UART_CTRL_RSTVL  : std_logic_vector(UART_CTRL_WIDTH_c-1 downto 0) := UART_CTRL_RSTVL_c;
		UART_INTEN_RSTVL : std_logic_vector(UART_NUM_INT_c-1 downto 0) := INT_RX_FIFO_EMPTY_c
	);
	port (
		-- Clock and reset (active low)
		clk  : in std_logic;
		rstn : in std_logic;
		-- UART
		rx_i : in std_logic;
		tx_o : out std_logic
	);
end uart_inverter;

architecture behavioral of uart_inverter is
	-- APB Requester signals
	signal pready_s    : std_logic_vector(0 downto 0) := (others => '0');
	signal pslverr_s   : std_logic_vector(0 downto 0) := (others => '0');
	signal prdata_s    : slv_array_t(0 downto 0);
	
	-- APB completer signals
	signal paddr_s   : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
	signal psel_s    : std_logic_vector(0 downto 0);
	signal penable_s : std_logic;
	signal pwrite_s  : std_logic;
	signal pwdata_s  : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
	
	-- Interrupts
	signal requester_interrupt_s : std_logic_vector(0 downto 0);
	signal uart_interrupt_s      : std_logic;
	
	-- UART signals
	signal uartrx_s : std_logic;
	signal uarttx_s : std_logic;
	signal invrx_s  : std_logic;
	signal invtx_s  : std_logic;
	
	
begin
	
	-- APB requester, or bus master
  REQ: entity work.apb_requester(behavioral)
	generic map(
		-- Bus widths
		APB_DATA_WIDTH => APB_DATA_WIDTH,
		APB_ADDR_WIDTH => APB_ADDR_WIDTH
	)
	port map(
		clk  => clk,
	  rstn => rstn,
	  
	  -- APB3 REQUESTER SIGNALS
	  paddr_o   => paddr_s,
	  psel_o    => psel_s,
	  penable_o => penable_s,
	  pwrite_o  => pwrite_s,
	  pwdata_o  => pwdata_s,
	  
	  -- APB3 COMPLETER SIGNALS
    pready_i  => pready_s,
		prdata_i  => prdata_s,
    pslverr_i => pslverr_s,

    -- Interrupt
    interrupt_i => requester_interrupt_s
	);

	-- APB completer, or peripheral
	COMP: entity work.apb_uart(behavioral)
	generic map(
		-- Bus widths
		APB_DATA_WIDTH   => APB_DATA_WIDTH,               -- Width of the APB data bus
		APB_ADDR_WIDTH   => APB_ADDR_WIDTH,               -- Width of the address bus
		-- UART FIFOs size
		UART_FIFO_SIZE_E => UART_FIFO_SIZE_E,             -- UART FIFOs size = 2^FIFO_SIZE_E
		FIFO_EDAC_WIDTH  => FIFO_EDAC_WIDTH,
		FIFO_ENABLE_EDAC => FIFO_ENABLE_EDAC,
		-- Memory-mapped registers reset values
		UART_FBAUD_RSTVL => UART_FBAUD_RSTVL,
		UART_CTRL_RSTVL  => UART_CTRL_RSTVL,
		UART_INTEN_RSTVL => UART_INTEN_RSTVL
	)
	port map(
		-- Clock and negated reset
		clk       => clk,
		rstn      => rstn,
		-- AMBA 3 APB
		paddr_i   => paddr_s,
		psel_i    => psel_s(0),
		penable_i => penable_s,
		pwrite_i  => pwrite_s,
		pwdata_i  => pwdata_s,
		prdata_o  => prdata_s(0),
		pready_o  => pready_s(0),
		pslverr_o => pslverr_s(0),
		-- UART 
		rx_i      => uartrx_s,
		tx_o      => uarttx_s,
		-- Interrupt interrupt if UART rx FIFO is NOT empty
		int_o     => uart_interrupt_s
	);

	-- Interrupt the requester when the UART rx FIFO is not empty
	requester_interrupt_s(0) <= not uart_interrupt_s;
	
	-- Drive UART input and inverter output
	uartrx_s <= rx_i;
	tx_o <= uarttx_s;

end behavioral;