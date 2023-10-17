<p align="center"><b>UART controller</b></p>

Description of a UART controller as a memory-mapped peripheral, licensed under CERN Open Hardware License OHL-S v2.

The peripheral's parallel interface is based on the AMBA 3 APB protocol, but we do not claim compliance with it through ARM's MicroPack V1.1.

### Characteristics:
<pre>
- UART word: 8 bits
- Stop bits: 1 or 2 bits
- Parity: None, even or odd
- Rx sampling: Majority-voted 3-bit shift-register with 8x oversampling, w/ baud rate as reference
- Tx/Rx FIFOs: up to 1024 words each
- Hardware flow control: none (yet)
- ECC: none or 2x Hamming [7,4] on each 8-bit UART word in the FIFOs.
</pre>

### Design patterns:
<pre>
- Fully synchronous, with sync. resets;
- Relevant memory-mapped registers have configurable reset values;
- Parameterizable designs
</pre>

### Register address map
<pre>
0x00000000 (r/w) UART data transmission/reception double register (tx: write-only, rx: read-only)
0x00000004 (r/w) UART frequency/baud ratio register: floor(clk_freq/baud_rate)
0x00000008 (r/w) UART control register
    [0]     Stop bit: LOW for one, high for TWO stop bits
    [1]     Parity enable
    [2]     Parity select: LOW for odd, HIGH for even
    [3-10]  Tx FIFO watermark
    [11-18] Rx FIFO watermark
0x0000000C (r/w) UART interrupt enable
    [0] Tx FIFO full
    [1] Rx FIFO full
    [2] Tx FIFO empty
    [3] Rx FIFO empty
    [4] Tx FIFO positions occupied < watermark
    [5] Rx FIFO positions occupied > watermark
0x00000010 (r/-) UART interrupt pending register - read-only and driven by the conditions alone
    [0] Tx FIFO full
    [1] Rx FIFO full
    [2] Tx FIFO empty
    [3] Rx FIFO empty
    [4] Tx FIFO positions occupied < watermark
    [5] Rx FIFO positions occupied > watermark
</pre>

## Organization of the repository:
All design source files are kept in the /sources directory, while their testbenches are kept in the /testbenches directory.

### Design files (in compile order)
<pre>
1) pkg_apbuart.vhd                - Definition of constants, types and synthesis-time functions
2) apb_requester.vhd              - APB bus requester which reads data from a number of peripherals, inverts and writes it back
3) hamming_nibble_encoder.vhd     - [7,4] Hamming encoder
4) hamming_nibble_decoder.vhd     - [7,4] Hamming decoder
5) hamming_byte_encoder.vhd       - [14,8] Hamming encoder, made with 2 Hamming nibble encoders
6) hamming_byte_decoder.vhd       - [14,8] Hamming decoder, made with 2 Hamming nibble decoders
7) dp_fifo.vhd                    - Dual-port FIFO w/ configurable size and possible nibble-wise error correction
8) apb_uart.vhd                   - UART controller
9) uart_inverter.vhd              - Entity formed by UART controller and APB requester, which inverts sends on tx_o the data from rx_i inverted
10) inverter_chain.vhd            - Parameterizable chain of UART inverters
</pre>

### Testbenches
<pre>
tb_hamming_nibble.vhd             - Exhaustive single-bit fault injection between hamming_nibble_encoder and hamming_nibble_decoder
tb_hamming_byte.vhd               - Exhaustive single-bit fault injection between hamming_byte_encoder and hamming_byte_decoder
tb_dp_fifo.vhd                    - Trivial tests with dp_fifo
tb_apb_uart.vhd                   - Test apb_uart in loopback with bursts of APB writes and reads
tb_uart_inverter.vhd              - Test uart_inverter with apb_uart as support
tb_inverter_chain.vhd             - Test inverter_chain with apb_uart as support
</pre>
