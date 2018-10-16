----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/13/2018 04:35:39 PM
-- Design Name: 
-- Module Name: ethernet_top - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ethernet_top is
    generic (
        ram_data_width : natural := 8;
        ram_addr_width : natural := 11 -- 2^11
    );
    Port ( 
           -- in/out 
           in_data      : in std_logic_vector (7 downto 0); -- data from the controller
           out_data      : out std_logic_vector (7 downto 0); -- data to the controller
           
           -- MII rx inputs
           rxdata_4     : in std_logic_vector(3 downto 0);
           rxdv_4       : in std_logic;            -- receive data valid
           -- MII tx outputs
           txdata_4     : out std_logic_vector(3 downto 0);
           txen_4:            out std_logic;        -- tx enable
           -- other MII signals
           col          : in std_logic;
           drop         : buffer std_logic;
           -- Clocks and reset
           clk          : in std_logic;  -- assume this will always be slower than the MII clk
           rst          : in std_logic;
           mii_tx_clk   : in std_logic;
           mii_rx_clk   : in std_logic;
           
           rx_full      : out std_logic;
           tx_full      : out std_logic;
           
           read_enable  : in std_logic;
           write_enable : in std_logic  
         );
end ethernet_top;

architecture rtl of ethernet_top is

    component ethernet_transceiver is
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

            rxdata:	out std_logic_vector(7 downto 0);	-- 8 bits wide
            rxdv:		out std_logic;										-- receive data valid
            txdata:	in std_logic_vector(7 downto 0);	-- 8 bits wide
            txen:		in std_logic;											-- tx enable
            -- status outputs
            drop:			buffer std_logic;	-- indicates the current frame should be dropped
            rx_pkt_len_out:    out std_logic_vector(10 downto 0);
            rx_pkt_done:   out std_logic
        );
    end component;
    
    component fifo_buffer is
    
        generic (
            fifo_depth : natural := 2048; -- 2048x8
            data_width : natural := 8;
            addr_width : natural := 11 -- 2^11
                );
    
        Port ( wclk : in STD_LOGIC;
               rclk : in STD_LOGIC; 
               reset : in STD_LOGIC;
               read : in STD_LOGIC;
               write : in STD_LOGIC;
               write_data : in STD_LOGIC_VECTOR (data_width - 1 downto 0);
               empty_out : out STD_LOGIC;
               full_out : out STD_LOGIC;
               read_data : out STD_LOGIC_VECTOR (data_width - 1 downto 0)
             );
        
    end component;

    signal mii_rx_data          : std_logic_vector(7 downto 0) := (others => '0');
    signal mii_tx_data          : std_logic_vector(7 downto 0) := (others => '0');
    signal fifo_tx_data         : std_logic_vector(7 downto 0) := (others => '0');
    signal mii_rx_valid         : std_logic := '0';
    signal mii_tx_enable        : std_logic := '0';
    signal mii_tx_en            : std_logic := '0';
    
    signal rx_pkt_len           : std_logic_vector(10 downto 0) := (others => '0');
    signal rx_pkt_done          : std_logic := '0';
    
    signal write_tx_fifo        : std_logic := '0';
    signal tx_empty             : std_logic := '0';
    signal rx_empty             : std_logic := '0';

    signal nibble_count         : std_logic := '0';

begin

    ethernet: ethernet_transceiver
        port map (
            -- MII signals
            rxclk       => mii_rx_clk,
            txclk       => mii_tx_clk,
            rxdata_4    => rxdata_4,
            rxdv_4      => rxdv_4,
            txdata_4    => txdata_4,
            txen_4      => txen_4,
            col         => col,
            reset       => rst,
            -- FIFO signals
            rxdata      => mii_rx_data,
            rxdv        => mii_rx_valid,
            txdata      => fifo_tx_data,
            txen        => mii_tx_en,
            drop        => drop,
            rx_pkt_len_out => rx_pkt_len,
            rx_pkt_done => rx_pkt_done
        );
        
    tx_fifo: fifo_buffer
        port map (
            wclk        => clk,
            rclk        => mii_tx_clk,
            reset       => rst,
            read        => mii_tx_en,
            write       => write_enable, 
            write_data  => in_data,
            empty_out   => tx_empty,
            full_out    => tx_full,
            read_data   => mii_tx_data
       );
        
    rx_fifo: fifo_buffer
        port map (
            wclk        => mii_rx_clk,
            rclk        => clk,
            reset       => rst,
            read        => read_enable,
            write       => mii_rx_valid, 
            write_data  => mii_rx_data,
            empty_out   => rx_empty,
            full_out    => rx_full,
            read_data   => out_data
        );

    start_tx : process(mii_tx_clk, rst, write_enable)
    
    begin
        if rst = '1' then
            mii_tx_en <= '0';
            nibble_count <= '0';
            
        elsif falling_edge(write_enable) then
            mii_tx_en <= '1';
        
        -- tx_empty changes to 1 when the last byte is read from 
        -- the FIFO buffer.  This means we still have 2 more
        -- nibbles to send on the mii_tx line.  The mii_tx_en 
        -- line needs to stay high until these are sent.
        elsif rising_edge(mii_tx_clk) then
            if tx_empty = '1' then
                if nibble_count = '1' then
                    mii_tx_en <= '0';
                    nibble_count <= '0';
                else
                    nibble_count <= '1';
                end if;
            else
                nibble_count <= '0';
            end if;
        end if;
    end process;

    txdata_process : process(mii_tx_clk, rst)
    
    begin
        if rising_edge(mii_tx_clk) then
            if rst = '1' then
                write_tx_fifo <= '0';
                fifo_tx_data <= (others => '0');
            else
               if mii_tx_en = '1' then
                    fifo_tx_data <= mii_tx_data;
               end if;
            
            end if;
        end if;  
    end process;
    
    

end rtl;
