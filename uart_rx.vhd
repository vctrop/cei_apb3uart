-------------------------------------------------------------------------------
-- DESIGN UNIT  : UART RX                                                    --
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

entity UART_RX is
	port(
		clk         : in std_logic;
		rst         : in std_logic;
		baud_av     : in std_logic;
		baud_in     : in std_logic_vector(15 downto 0);
		rx          : in std_logic;
		data_out    : out std_logic_vector(7 downto 0);
		data_av     : out std_logic
	);
end UART_RX;

architecture behavioral of UART_RX is

	signal clkCounter: integer range 0 to 65535;
	signal bitCounter: integer range 0 to 8;
	signal sampling: std_logic;

	type State is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
	signal currentState: State;

	signal rx_data         : std_logic_vector(7 downto 0);
	signal reg_freq_baud   : std_logic_vector(15 downto 0);

begin

	-- Frequency/BaudRate register
	process(clk,rst)
	begin
	if rst = '1' then
		reg_freq_baud <= x"00d9";  -- floor(25e6 / 115200) = 217 is the standard frequency-baud rate for 115200 bps
	elsif rising_edge(clk) then
		if baud_av = '1' then
			reg_freq_baud <= baud_in;
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
				if clkCounter = to_integer(unsigned(reg_freq_baud))-1 then
					clkCounter <= 0;
				else
					clkCounter <= clkCounter + 1;
				end if;
			else
				clkCounter <= 0;
			end if;
		end if;
	end process;
	sampling <= '1' when clkCounter = to_integer(unsigned(reg_freq_baud))/2 else '0';  

	-- Data reception state machine
	process(clk,rst)
	begin
		if rst = '1' then
			bitCounter <= 0;
			rx_data <= (others=>'0');
			currentState <= IDLE;

		elsif rising_edge(clk) then
			case currentState is
				when IDLE =>
					bitCounter <= 0;
					if rx = '0' then
						currentState <= START_BIT;
					else
						currentState <= IDLE;
					end if;

				when START_BIT =>
					if sampling = '1' then
						currentState <= DATA_BITS;
					else
						currentState <= START_BIT;
					end if;                    

				when DATA_BITS =>
					if bitCounter = 8 then
						currentState <= STOP_BIT;
					elsif sampling = '1' then           
						rx_data <= rx & rx_data(7 downto 1);
						bitCounter <= bitCounter + 1;
						currentState <= DATA_BITS;
					else
						currentState <= DATA_BITS;
					end if;
						
				when STOP_BIT =>
					if rx = '1' and sampling = '1' then
						currentState <= IDLE;
					else
						currentState <= STOP_BIT;
					end if;

			end case;
		end if;
	end process;

	data_out <= rx_data;
	data_av <= sampling when currentState = STOP_BIT else '0';

end behavioral;