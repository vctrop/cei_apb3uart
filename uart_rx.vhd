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
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity uart_rx is
	generic(
		-- Baud divider default value should be floor(freq/baudrate), or 1 for simulation
		BAUD_DIV_DEFAULT : std_logic_vector(15 downto 0) := x"0001"
	);
	port(
		clk       : in std_logic;
		rst       : in std_logic;
		--
		baud_av_i : in std_logic;
		baud_i    : in std_logic_vector(15 downto 0);
		rx_i      : in std_logic;
		--
		data_o    : out std_logic_vector(7 downto 0);
		data_av_o : out std_logic
	);
end uart_rx;

architecture behavioral of uart_rx is
	
	type state_t is (Sidle, Sstart_bit, Sdata_bits, Sstop_bit);
	signal reg_state: state_t;
	
	signal clk_counter_s : integer range 0 to 65535;
	signal bit_counter_s : integer range 0 to 8;
	signal sampling_s    : std_logic;
	signal reg_rx_data   : std_logic_vector(7 downto 0);
	signal reg_freq_baud : std_logic_vector(15 downto 0);

begin

	-- User-defined registers:
	-- Baud rate divider register
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				reg_freq_baud <= BAUD_DIV_DEFAULT;
			else
				-- 
				if baud_av_i = '1' then
					reg_freq_baud <= baud_i;
				end if;
				
			end if;
		end if;
		end process;
	
	process(clk)
	begin
		if rst = '1' then
			clk_counter_s <= 0;
		elsif rising_edge(clk) then
			if reg_state /= Sidle then
				if clk_counter_s = to_integer(unsigned(reg_freq_baud))-1 then
					clk_counter_s <= 0;
				else
					clk_counter_s <= clk_counter_s + 1;
				end if;
			else
				clk_counter_s <= 0;
			end if;
		end if;
	end process;
	
	-- Data reception state machine
	sampling_s <= '1' when clk_counter_s = to_integer(unsigned(reg_freq_baud))/2 else '0';  

	process(clk,rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				bit_counter_s <= 0;
				reg_rx_data <= (others=>'0');
				reg_state <= Sidle;
			end if;
		else
			case reg_state is
				when Sidle =>
					bit_counter_s <= 0;
					if rx_i = '0' then
						reg_state <= Sstart_bit;
					else
						reg_state <= Sidle;
					end if;

				when Sstart_bit =>
					if sampling_s = '1' then
						reg_state <= Sdata_bits;
					else
						reg_state <= Sstart_bit;
					end if;                    

				when Sdata_bits =>
					if bit_counter_s = 8 then
						reg_state <= Sstop_bit;
					elsif sampling_s = '1' then           
						reg_rx_data <= rx_i & reg_rx_data(7 downto 1);
						bit_counter_s <= bit_counter_s + 1;
						reg_state <= Sdata_bits;
					else
						reg_state <= Sdata_bits;
					end if;
						
				when Sstop_bit =>
					if rx_i = '1' and sampling_s = '1' then
						reg_state <= Sidle;
					else
						reg_state <= Sstop_bit;
					end if;

			end case;
		end if;
	end process;
	
	-- Entity outputs
	data_o <= reg_rx_data;
	data_av_o <= sampling_s when reg_state = Sstop_bit else '0';

end behavioral;