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

entity hamming_byte_encoder is
	port (
		-- Takes a byte as input and apply Hamming [7,4] to each of its halves, resulting in a 14-bit encoding with the possibility of DEC
		data_i : in std_logic_vector(7 downto 0);
		data_o : out std_logic_vector(13 downto 0)
	);
end hamming_byte_encoder;

architecture behavioral of hamming_byte_encoder is
	-- 
	signal encoded_nibble_a_s : std_logic_vector(6 downto 0);
	signal encoded_nibble_b_s : std_logic_vector(6 downto 0);
	signal encoded_msg_s : std_logic_vector(13 downto 0);
	
begin
	
	-- Nibble A encoder
	NIB_A_ENC: entity work.hamming_nibble_encoder(behavioral)
	port map(
		data_i => data_i(3 downto 0),
		data_o => encoded_nibble_a_s
	);
	
	-- Nibble B encoder
	NIB_B_ENC: entity work.hamming_nibble_encoder(behavioral)
	port map(
		data_i => data_i(7 downto 4),
		data_o => encoded_nibble_b_s
	);
	
	-- Assemble encoded byte (14, 8) from 2x Hamming (7, 4) encoded nibbles
	-- Encoded message [13:7]  = encoded nibble B
	-- Encoded message [6:0] = encoded nibble A
	encoded_msg_s(13 downto 7) <= encoded_nibble_b_s;
	encoded_msg_s(6 downto 0)  <= encoded_nibble_a_s;
	
	-- Drive output
	data_o <= encoded_msg_s;
	
end behavioral;