-------------------------------------------------------------------------------
-- Ethernet
-- --------
-- High-level entity encompasssing all Ethernet functionality
--
-- Original inspiration from here:
-- http://www.ece.ualberta.ca/~elliott/ee552/studentAppNotes/2001_w/interfacing/ethernet_mii/eth_mii.html
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library work;

entity ethernet_transceiver is

	port(
		-----------------------------
		-- Transceiver/MII signals --
		-----------------------------

		-- MII clocks
		rxclk:		in std_logic;			-- receive clocks
		txclk:		in std_logic;			-- transmit clocks

		-- rx inputs
		rxdata_4:		in std_logic_vector(3 downto 0);
		rxdv_4:			in std_logic;			-- receive data valid

		-- tx outputs
		txdata_4:		out std_logic_vector(3 downto 0);
		txen_4:			out std_logic;		-- tx enable

		-- status inputs
		col:				in std_logic;			-- collision indicators

		-----------------------
		-- External signals --
		-----------------------

		reset:	in std_logic;

		-- data I/O
		rxdata:	out std_logic_vector(7 downto 0);	-- 8 bits wide
		rxdv:		out std_logic;										-- receive data valid
		txdata:	in std_logic_vector(7 downto 0);	-- 8 bits wide
		txen:		in std_logic;											-- tx enable

		-- status outputs
		drop:			buffer std_logic;	-- indicates the current frame should be dropped
		
		rx_pkt_len_out:    out std_logic_vector(10 downto 0);
		rx_pkt_done:   out std_logic
		
		
	);

end entity ethernet_transceiver;

architecture eth_arch of ethernet_transceiver is

    -- The drop and reset signals both serve as a reset...
    -- OR them together into the clear signal
    signal clear:							std_logic;

    component receiver is
        port (
            
            clk:										in std_logic;
            clr:										in std_logic;
            
            -- from MII
            rxdata_4:								in std_logic_vector(3 downto 0);
            rxdv_4:									in std_logic;
            
            -- to output
            rxdata_8:								out std_logic_vector(7 downto 0);
            rxdv_8:									out std_logic;
            packet_len_out:                         out std_logic_vector(10 downto 0);
            packet_done:                            out std_logic
        );
    end component receiver;
    
    component transmitter is
        port (
            
            clk:										in std_logic;
            clr:										in std_logic;
            
            -- to MII
            txdata_4:								out std_logic_vector(3 downto 0);
            txen_4:									out std_logic;
        
            -- from input
            txdata_8:								in std_logic_vector(7 downto 0);
            txen_8:									in std_logic
        );	
    end component transmitter;

begin
    drop <= col;
    clear <= reset or drop;

    trans: transmitter
        port map(
    
            -- clock
            clk => txclk,
    
            -- 4 bit nibbles for MII
            txen_4 => txen_4,
            txdata_4 => txdata_4,
    
            -- clear if 'clear' is asserted
            clr => clear,
    
            -- 8 bytes in
            txen_8 => txen,
            txdata_8 => txdata
        );
    
    recv: receiver
        port map(
    
            -- clock
            clk => rxclk,
    
            -- 4 bit nibbles for MII
            rxdv_4 => rxdv_4,
            rxdata_4 => rxdata_4,
    
            -- clear if 'clear' is asserted
            clr => clear,
    
            -- 8 bytes out
            rxdv_8 => rxdv,
            rxdata_8 => rxdata,
            packet_len_out => rx_pkt_len_out,
            packet_done => rx_pkt_done
        );

end architecture eth_arch;