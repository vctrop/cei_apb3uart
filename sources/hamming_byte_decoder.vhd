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

entity hamming_byte_decoder is
	port (
		-- Takes a Hamming [14,8] encoded message, decodes each of its halves with a Hamming [7,4] code and assemble the decoded byte
		data_i : in std_logic_vector(13 downto 0);
		data_o : out std_logic_vector(7 downto 0)
	);
end hamming_byte_decoder;

architecture behavioral of hamming_byte_decoder is
	-- 
	signal decoded_nibble_a_s : std_logic_vector(3 downto 0);
	signal decoded_nibble_b_s : std_logic_vector(3 downto 0);
	signal decoded_msg_s : std_logic_vector(7 downto 0);
	
begin
	
	-- Nibble A decoder
	NIB_A_DEC: entity work.hamming_nibble_decoder(behavioral)
	port map(
		data_i => data_i(6 downto 0),
		data_o => decoded_nibble_a_s
	);
	
	-- Nibble B decoder
	NIB_B_DEC: entity work.hamming_nibble_decoder(behavioral)
	port map(
		data_i => data_i(13 downto 7),
		data_o => decoded_nibble_b_s
	);
	
	-- Assemble decoded message from 2x Hamming (7, 4) decoded nibbles
	-- Decoded message [7:4] = decoded nibble B
	-- Decoded message [3:0] = decoded nibble A
	decoded_msg_s(7 downto 4) <= decoded_nibble_b_s;
	decoded_msg_s(3 downto 0) <= decoded_nibble_a_s;
	
	-- Drive output
	data_o <= decoded_msg_s;
	
end behavioral;