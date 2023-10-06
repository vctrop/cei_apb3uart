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
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity uart_tx is
	generic(
		-- Baud divider default value should be floor(freq/baudrate), or 1 for simulation
		BAUD_DIV_DEFAULT : std_logic_vector(15 downto 0) := x"0001";
		--
		BAUD_DIV_ADDR : std_logic_vector(1 downto 0);
		TX_DATA_ADDR  : std_logic_vector(1 downto 0)
	);
	port(
		clk       : in std_logic;
		rst       : in std_logic;
		--
		data_av_i : in std_logic;
		address_i : in std_logic_vector(1 downto 0);
		data_i    : in std_logic_vector(15 downto 0);
		--
		tx_o      : out std_logic;
		ready_o   : out std_logic     -- When '1', module is available to send a new byte
	);
end uart_tx;

architecture behavioral of uart_tx is
	type state_t is (SSidle, Sstart_bit, Sdata_bits, Sstop_bit);
	signal reg_state: state_t;
		
	signal clk_counter_s : integer range 0 to 65535;
	signal bit_counter_s : integer range 0 to 8;
	signal reg_tx_data   : std_logic_vector(7 downto 0);
	signal reg_freq_baud : std_logic_vector(15 downto 0);

begin

	-- User-defined registers:
	-- Baud rate divider register
	process(clk,rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				-- Default value
				reg_freq_baud <= BAUD_DIV_DEFAULT;
			elsif data_av_i = '1' and address_i = BAUD_DIV_ADDR then
				-- Write access to 
				reg_freq_baud <= data_i; 
			end if;
		end if;
	end process;

	-- Clock counter
	process(clk,rst)
	begin
		if rst = '1' then
			clk_counter_s <= 0;
		elsif rising_edge(clk) then
			if reg_state /= SSidle then
				if clk_counter_s = to_integer(unsigned(reg_freq_baud)) - 1 then
					clk_counter_s <= 0;
				else
					clk_counter_s <= clk_counter_s + 1;
				end if;
			else
				clk_counter_s <= 0;
			end if;
		end if;
	end process;

	-- Data transmission state machine
	process(clk,rst)
	begin
		if rst = '1' then
			bit_counter_s <= 0;
			reg_tx_data <= (others=>'0');
			reg_state <= SSidle;

		elsif rising_edge(clk) then
			case reg_state is
				when SSidle =>
					bit_counter_s <= 0;
					if data_av_i = '1' and address_i = TX_DATA_ADDR then
							reg_tx_data <= data_i(7 downto 0);
							reg_state <= Sstart_bit;
					else
							reg_state <= SSidle;
					end if;

				when Sstart_bit =>
					if clk_counter_s = to_integer(unsigned(reg_freq_baud)) - 1 then
						reg_state <= Sdata_bits;
					else
						reg_state <= Sstart_bit;
					end if;                    
									
				when Sdata_bits =>
					if bit_counter_s = 8 then
						reg_state <= Sstop_bit;
					elsif clk_counter_s = to_integer(unsigned(reg_freq_baud)) - 1 then           
						reg_tx_data <= '0' & reg_tx_data(7 downto 1);
						bit_counter_s <= bit_counter_s + 1;
						reg_state <= Sdata_bits;
					else
						reg_state <= Sdata_bits;
					end if;
							
				when Sstop_bit =>
					if clk_counter_s = to_integer(unsigned(reg_freq_baud)) - 1 then
						reg_state <= SSidle;
					else
						reg_state <= Sstop_bit;
					end if;

			end case;
		end if;
	end process;

	-- Entity output
	tx_o <= '0' when reg_state = Sstart_bit else 
				reg_tx_data(0) when reg_state = Sdata_bits else
				'1';    -- SSidle, Sstop_bit
					
	ready_o <= '1' when reg_state = SSidle else '0';

end behavioral;
