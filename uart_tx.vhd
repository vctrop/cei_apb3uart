-------------------------------------------------------------------------------
-- DESIGN UNIT  : UART TX                                                    --
-- DESCRIPTION  : Start bit/8 data bits/Stop bit                             --
--              :                                                            --
-- AUTHOR       : Everton Alceu Carara                                       --
-- CREATED      : May, 2016                                                  --
-- VERSION      : 1.1                                                        --
-- HISTORY      : Version 1.0 - May, 2016 - Everton Alceu Carara             --
--              : Version 1.1 - June, 2019 - Victor O. Costa, Julio Costella --         
-------------------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity UART_TX is
	generic(
		FREQ_BAUD_ADDR  : std_logic_vector(1 downto 0);
		TX_DATA_ADDR    : std_logic_vector(1 downto 0)
	);
	port(
		clk         : in std_logic;
		rst         : in std_logic;
		data_av     : in std_logic;
		address     : in std_logic_vector(1 downto 0);
		data_in     : in std_logic_vector(15 downto 0);
		tx          : out std_logic;
		ready       : out std_logic     -- When '1', module is available to send a new byte
	);
end UART_TX;

architecture behavioral of UART_TX is

	signal clkCounter: integer range 0 to 65535;
	signal bitCounter: integer range 0 to 8;
		
	type State is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
	signal currentState: State;

	signal tx_data         : std_logic_vector(7 downto 0);
	signal reg_freq_baud   : std_logic_vector(15 downto 0);
     
begin
    
	-- Frequency/BaudRate register
	process(clk,rst)
	begin
		if rst = '1' then
			-- floor(25e6 / 115200) = 217 is the standard frequency-baud rate for 115200 bps
			reg_freq_baud <= x"00d9";  
		elsif rising_edge(clk) then
			if data_av = '1' and address = FREQ_BAUD_ADDR then
				reg_freq_baud <= data_in;
			end if;
		end if;
	end process;

	-- Clock counter
	process(clk,rst)
	begin
		if rst = '1' then
			clkCounter <= 0;
		elsif rising_edge(clk) then
			if currentState /= IDLE then
				if clkCounter = to_integer(unsigned(reg_freq_baud)) - 1 then
					clkCounter <= 0;
				else
					clkCounter <= clkCounter + 1;
				end if;
			else
				clkCounter <= 0;
		end if;
		end if;
	end process;

	-- Data transmission state machine
	process(clk,rst)
	begin
		if rst = '1' then
			bitCounter <= 0;
			tx_data <= (others=>'0');
			currentState <= IDLE;

		elsif rising_edge(clk) then
			case currentState is
				when IDLE =>
					bitCounter <= 0;
					if data_av = '1' and address = TX_DATA_ADDR then
							tx_data <= data_in(7 downto 0);
							currentState <= START_BIT;
					else
							currentState <= IDLE;
					end if;

				when START_BIT =>
					if clkCounter = to_integer(unsigned(reg_freq_baud)) - 1 then
						currentState <= DATA_BITS;
					else
						currentState <= START_BIT;
					end if;                    
									
				when DATA_BITS =>
					if bitCounter = 8 then
						currentState <= STOP_BIT;
					elsif clkCounter = to_integer(unsigned(reg_freq_baud)) - 1 then           
						tx_data <= '0' & tx_data(7 downto 1);
						bitCounter <= bitCounter + 1;
						currentState <= DATA_BITS;
					else
						currentState <= DATA_BITS;
					end if;
							
				when STOP_BIT =>
					if clkCounter = to_integer(unsigned(reg_freq_baud)) - 1 then
						currentState <= IDLE;
					else
						currentState <= STOP_BIT;
					end if;

			end case;
		end if;
	end process;

	tx <= '0' when currentState = START_BIT else 
				tx_data(0) when currentState = DATA_BITS else
				'1';    -- IDLE, STOP_BIT
					
	ready <= '1' when currentState = IDLE else '0';


end behavioral;
