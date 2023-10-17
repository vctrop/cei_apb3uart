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

entity hamming_nibble_encoder is
	port (
		-- Takes a nibble as message and outputs a 7-bit Hamming encoding (Hamming [7,4])
		data_i : in std_logic_vector(3 downto 0);
		data_o : out std_logic_vector(6 downto 0)
	);
end hamming_nibble_encoder;

architecture behavioral of hamming_nibble_encoder is
	--
	signal raw_msg_s : std_logic_vector(3 downto 0);
	signal parity_s      : std_logic_vector(2 downto 0); 
	signal encoded_msg_s : std_logic_vector(6 downto 0);
	
begin
	-- Hamming [7,4] representation
	---- Currently ignoring the error detection parity bit p0
	---- p1 = d2 + d3 + d4
	---- p2 = d1 + d3 + d4
	---- p3 = d1 + d2 + d4
	---- Encode [p1, p2, d1, p3, d2, d3, d4]
	-- Signal represenation:
	---- data_i(0) : d4, ..., data_i(3) : d1
	---- parity_s(0) : p3, ..., parity_s(2) : p1
	--
	raw_msg_s <= data_i;
	
	--
	parity_s(0) <= raw_msg_s(2) xor (raw_msg_s(1) xor raw_msg_s(0));
	parity_s(1) <= raw_msg_s(3) xor (raw_msg_s(1) xor raw_msg_s(0));
	parity_s(2) <= raw_msg_s(3) xor (raw_msg_s(2) xor raw_msg_s(0));
	
	-- Encoded message: [p0, p1, d0, p2, d1, d2, d3]
	encoded_msg_s(0) <= raw_msg_s(0);
	encoded_msg_s(1) <= raw_msg_s(1);
	encoded_msg_s(2) <= raw_msg_s(2);
	encoded_msg_s(3) <= parity_s(0);
	encoded_msg_s(4) <= raw_msg_s(3);
	encoded_msg_s(5) <= parity_s(1);
	encoded_msg_s(6) <= parity_s(2);
	
	-- Drive output
	data_o <= encoded_msg_s;

end behavioral;