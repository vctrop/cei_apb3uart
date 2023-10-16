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
	
entity tb_hamming_byte is
end tb_hamming_byte;

architecture behavioral of tb_hamming_byte is
	-- Clock and reset (active low)
	signal clk : std_logic := '0';
	signal rstn : std_logic := '0';
	constant half_clk_period : time := 10 ns;
	constant clk_period : time := 2*half_clk_period;

	-- 
	signal msg_s         : unsigned(7 downto 0) := x"00";
	signal decoded_msg_s : std_logic_vector(7 downto 0);
	signal encoded_msg_s : std_logic_vector(13 downto 0);
	
	--
	signal faulty_encoded_msg_s : std_logic_vector(13 downto 0);
	
	-- Bit masks for fault injection
	constant MASK_BIT0_c : std_logic_vector(13 downto 0) := "00000000000001";
	constant MASK_BIT1_c : std_logic_vector(13 downto 0) := "00000000000010";
	constant MASK_BIT2_c : std_logic_vector(13 downto 0) := "00000000000100";
	constant MASK_BIT3_c : std_logic_vector(13 downto 0) := "00000000001000";
	constant MASK_BIT4_c : std_logic_vector(13 downto 0) := "00000000010000";
	constant MASK_BIT5_c : std_logic_vector(13 downto 0) := "00000000100000";
	constant MASK_BIT6_c : std_logic_vector(13 downto 0) := "00000001000000";
	constant MASK_BIT7_c : std_logic_vector(13 downto 0) := "00000010000000";
	constant MASK_BIT8_c : std_logic_vector(13 downto 0) := "00000100000000";
	constant MASK_BIT9_c : std_logic_vector(13 downto 0) := "00001000000000";
	constant MASK_BITA_c : std_logic_vector(13 downto 0) := "00010000000000";
	constant MASK_BITB_c : std_logic_vector(13 downto 0) := "00100000000000";
	constant MASK_BITC_c : std_logic_vector(13 downto 0) := "01000000000000";
	constant MASK_BITD_c : std_logic_vector(13 downto 0) := "10000000000000";
	
begin
	-- Clock and reset
	clk <= not clk after half_clk_period;
	rstn <= '1' after 5*clk_period;

	-- 
	DUV_ENC: entity work.hamming_byte_encoder(behavioral)
	port map(
		data_i => std_logic_vector(msg_s),
		data_o => encoded_msg_s
	);
	
	-- 
	DUV_DEC: entity work.hamming_byte_decoder(behavioral)
	port map(
		data_i => faulty_encoded_msg_s,
		data_o => decoded_msg_s
	);
	
	process
	begin
		wait until rstn = '1';
		
		for i in 0 to 15 loop
			-- Test all possible messages for a nibble
			msg_s <= to_unsigned(i, msg_s'length);
			
			-- Test decoder
			-- No data corruption
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s;
			
			-- W/ data corruption
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT0_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT1_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT2_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT3_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT4_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT5_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT6_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT7_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT8_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BIT9_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BITA_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BITB_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BITC_c;
			
			wait for clk_period;
			faulty_encoded_msg_s <= encoded_msg_s xor MASK_BITD_c;
			
		end loop;
		
	end process;

end behavioral;
