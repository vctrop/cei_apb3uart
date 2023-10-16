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

entity hamming_nibble_decoder is
	port (
		-- Takes a 7-bit Hamming encoded (7,4) message and corrects single bit errors 
		data_i : in std_logic_vector(6 downto 0);
		data_o : out std_logic_vector(3 downto 0)
	);
end hamming_nibble_decoder;

architecture behavioral of hamming_nibble_decoder is
	signal encoded_msg_s     : std_logic_vector(6 downto 0);
	--
	signal parity_msg_s      : std_logic_vector(2 downto 0);
	signal parity_computed_s : std_logic_vector(2 downto 0);
	signal parity_xor_s      : std_logic_vector(2 downto 0);
	--
	signal toggle_bit_s      : unsigned(2 downto 0);
	-- 
	signal corrected_msg_s   : std_logic_vector(6 downto 0);
	signal corrected_data_s  : std_logic_vector(3 downto 0);
	
	
begin
	-- Hamming [7,4] representation
	---- Currently ignoring the error detection parity bit p0
	---- p1 = d2 + d3 + d4
	---- p2 = d1 + d3 + d4
	---- p3 = d1 + d2 + d4
	---- Encode [p1, p2, d1, p3, d2, d3, d4]
	-- Signal represenation:
	---- data_i(0) : d4, ..., data_i(3) : d1
	---- parity_msg_s(0) : p3, ..., parity_msg_s(2) : p1
	--
	encoded_msg_s <= data_i;
	
	-- Recover parity from encoded message
	parity_msg_s(0) <= encoded_msg_s(3);
	parity_msg_s(1) <= encoded_msg_s(5);
	parity_msg_s(2) <= encoded_msg_s(6);
	
	-- Compute parity of encoded message
	parity_computed_s(0) <= encoded_msg_s(2) xor (encoded_msg_s(1) xor encoded_msg_s(0));
	parity_computed_s(1) <= encoded_msg_s(4) xor (encoded_msg_s(1) xor encoded_msg_s(0));
	parity_computed_s(2) <= encoded_msg_s(4) xor (encoded_msg_s(2) xor encoded_msg_s(0));
	
	--
	parity_xor_s <= parity_msg_s xor parity_computed_s;
	-- toggle_bit_s <= 7 - unsigned(parity_xor_s);
	
	-- 
	-- GEN_TOG: for i in 6 downto 0 generate
		-- corrected_msg_s(i) <= not encoded_msg_s(i) when toggle_bit_s = i  else encoded_msg_s(i);
	-- end generate;
	
	--
	corrected_msg_s(0) <= not encoded_msg_s(0) when parity_xor_s = "111"  else encoded_msg_s(0);
	corrected_msg_s(1) <= not encoded_msg_s(1) when parity_xor_s = "011"  else encoded_msg_s(1);
	corrected_msg_s(2) <= not encoded_msg_s(2) when parity_xor_s = "101"  else encoded_msg_s(2);
	corrected_msg_s(3) <= not encoded_msg_s(3) when parity_xor_s = "001"  else encoded_msg_s(3);
	corrected_msg_s(4) <= not encoded_msg_s(4) when parity_xor_s = "110"  else encoded_msg_s(4);
	corrected_msg_s(5) <= not encoded_msg_s(5) when parity_xor_s = "010"  else encoded_msg_s(5);
	corrected_msg_s(6) <= not encoded_msg_s(6) when parity_xor_s = "100"  else encoded_msg_s(6);
	
	corrected_data_s(0) <= corrected_msg_s(0);
	corrected_data_s(1) <= corrected_msg_s(1);
	corrected_data_s(2) <= corrected_msg_s(2);
	corrected_data_s(3) <= corrected_msg_s(4);
	
	-- Drive output
	data_o <= corrected_data_s;

end behavioral;