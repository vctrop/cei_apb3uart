library ieee;
	use ieee.std_logic_1164.all;
	-- use ieee.numeric_std.all; 

--
	use work.pkg_apbuart_constants.all;
	
entity tb_uart_inverter is
end tb_uart_inverter;

architecture behavioral of tb_uart_inverter is
	-- Clock and reset (active low)
	signal clk : std_logic := '0';
	signal rstn : std_logic := '0';
	constant half_clk_period : time := 10 ns;
	constant clk_period : time := 2*half_clk_period;

	-- 
	signal uartrx_s : std_logic := '0';
	signal uarttx_s : std_logic;

	-- Supporter UART
	-- APB Completer signals
	signal paddr_s   : std_logic_vector(APB_ADDR_WIDTH_c-1 downto 0) := (others => '0');
	signal psel_s    : std_logic := '0';
	signal penable_s : std_logic := '0';
	signal pwrite_s  : std_logic := '0';
	signal pwdata_s  : std_logic_vector(APB_DATA_WIDTH_c-1 downto 0) := x"00000055";
	signal prdata_s  : std_logic_vector(APB_DATA_WIDTH_c-1 downto 0);
	-- 
	signal int_support_s : std_logic;
	
begin
	-- Clock and reset
	clk <= not clk after half_clk_period;
	rstn <= '1' after 5*clk_period;

	-- Support UART does what the Zynq should do in the final setup
	-- (i.e. stimulates the UART inverter and registers its ouput)
	SUPPORT_UART: entity work.apb_uart(behavioral)
	generic map(
		-- UART FIFOs size = 2^FIFOS_SIZE_E = 128
		UART_FIFO_SIZE_E => 7,
		-- Enbale only rx FIFO empty interrupt
		UART_INTEN_RSTVL => "001000"
	)
	port map(
		-- Clock and reset (active low)
		clk       => clk,
		rstn      => rstn,
		
		-- AMBA 3 APB
		paddr_i   => paddr_s,
		psel_i    => psel_s,
		penable_i => penable_s,
		pwrite_i  => pwrite_s,
		pwdata_i  => pwdata_s,
		prdata_o  => prdata_s,
		pready_o  => open,
		pslverr_o => open,
		
		-- UART 
		rx_i      => uarttx_s,
		tx_o      => uartrx_s,
		
		-- Interrupt
		int_o     => int_support_s
	);

	DUV : entity work.uart_inverter(behavioral)
	generic map(
		UART_FBAUD_RSTVL => UART_FBAUD_SIM_c
	)
	port map(
		clk  => clk,
		rstn => rstn,
		rx_i => uartrx_s,
		tx_o => uarttx_s
	);
	
	APB_PROC: process
	begin
		wait until rstn = '1';
		
		-- APB writes to the data register of the SUPPORT UART
		for i in 0 to 127 loop
			
			-- Setup phase
			wait for clk_period;
			paddr_s   <= x"00000000";
			pwrite_S  <= '1';
			psel_s    <= '1';
			penable_s <= '0';
			pwdata_s  <= not pwdata_s;
			-- Access phase
			wait for clk_period;
			penable_s <= '1';
			-- Idle phase
			wait for clk_period;
			psel_s    <= '0';
			penable_s <= '0';
			pwrite_s  <= '0';
			
		end loop;
		
		
		-- APB reads from the data register of the SUPPORT UART
		for i in 0 to 127 loop
			
			-- Wait interrupt (currently rx FIFO is not empty)
			wait until int_support_s = '0';
			-- Setup phase
			wait for clk_period;
			paddr_s   <= x"00000000";
			pwrite_S  <= '0';
			psel_s    <= '1';
			penable_s <= '0';
			-- Access phase
			wait for clk_period;
			penable_s <= '1';
			-- Idle phase
			wait for clk_period;
			psel_s    <= '0';
			penable_s <= '0';
			
		end loop;
		
	end process;

end behavioral;
