----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/30/2018 09:29:22 PM
-- Design Name: 
-- Module Name: ethernet_top_tb - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ethernet_top_tb is
--  Port ( );
end ethernet_top_tb;

architecture Behavioral of ethernet_top_tb is

    component ethernet_top is
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
    end component;

    signal clk          : std_logic := '0';
    signal rxclk        : std_logic := '0';
    signal txclk        : std_logic := '0';
    signal reset        : std_logic := '0';
    
    signal mii_rx       : std_logic_vector (3 downto 0);
    signal mii_rxdv     : std_logic := '0';
    signal mii_tx       : std_logic_vector (3 downto 0);
    signal mii_txen     : std_logic := '0';
    
    signal out_data     : std_logic_vector (7 downto 0) := (others => '0');
    signal rx_dv        : std_logic := '0';
    signal in_data      : std_logic_vector (7 downto 0) := (others => '0');
    signal tx_en        : std_logic := '0';
    
    signal drop         : std_logic := '0';
    signal collision    : std_logic := '0';
    
    signal rx_fifo_full : std_logic := '0';
    signal tx_fifo_full : std_logic := '0';
    
    constant clk_period    : time := 125 ns; -- 125ns == 8 MHz clock, 250ns == 4 MHz clock
    constant ETHCLK_period : time := 40 ns; -- 400ns == 2.5 MHz clock, 40ns == 25 MHz clock

begin

    uut: ethernet_top
        port map (
            in_data => in_data,
            out_data => out_data,
            rxdata_4 => mii_rx,
            rxdv_4 => mii_rxdv,
            txdata_4 => mii_tx,
            txen_4 => mii_txen,
            col => collision,
            drop => drop,
            clk => clk,
            rst => reset,
            mii_tx_clk => txclk,
            mii_rx_clk => rxclk,
            rx_full => rx_fifo_full,
            tx_full => tx_fifo_full,
            read_enable => rx_dv,
            write_enable => tx_en 
        );
        
    externalclk : process
        begin
            clk <= '1';
            wait for clk_period/2;
            clk <= '0';
            wait for clk_period/2;
        end process;
        
    -- tx and rx clocks are synced when they come from the master device
    ETHCLK_process : process
    begin
        rxclk <= '1';
        txclk <= '1';
        wait for ETHCLK_period/2;
        rxclk <= '0';
        txclk <= '0';
        wait for ETHCLK_period/2;
    end process;  
    
    reset_process : process
    begin
        reset <= '1';
        wait for clk_period * 10;
        reset <= '0';
        wait;
        end process;
        
        
    -- simulate transmission from master device to vhdl
    RXDATA_process : process is
        procedure mii_rx_cycle(data : in std_logic_vector(3 downto 0) := "XXXX";
                           dv   : in std_logic                    := 'X') is
        begin
            mii_rxdv  <= dv;
            mii_rx    <= data;
            wait for ETHCLK_period;
        end procedure; 
    
        procedure mii_rx_stimulate(
                    data : in std_logic_vector(7 downto 0) := "XXXXXXXX";
                    dv   : in std_logic                    := 'X') is            
        begin
            mii_rx_cycle(data(7 downto 4), dv);
            mii_rx_cycle(data(3 downto 0), dv);
        end procedure;        
      
    begin
    
        -- all lines go to zero
        mii_rx_stimulate("00000000", '0');
        
        wait for clk_period*12;
        
        -- Preamble 0x55
        for i in 0 to 6 loop
            mii_rx_stimulate("01010101", '1');
        end loop;
        -- SFD  0x5D
        mii_rx_stimulate("01011101", '1');
        
        -- MAC Address FF:FF:FF:FF:FF:FF
        for i in 0 to 5 loop
            mii_rx_stimulate("11111111", '1');
        end loop;
        
        -- Note that the nibbles are swapped
        -- MAC Address DE:AD:BE:EF:BA:5E
        mii_rx_stimulate("11101101", '1');
        mii_rx_stimulate("11011010", '1');
        mii_rx_stimulate("11101011", '1');
        mii_rx_stimulate("11111110", '1');
        mii_rx_stimulate("10101011", '1');
        mii_rx_stimulate("11100101", '1');
        
        -- Type BE:EF
        mii_rx_stimulate("11101011", '1');
        mii_rx_stimulate("11111110", '1');
        
        -- Data 68:65:6c:6c:6f:20:77:6f:72:6c:64
        mii_rx_stimulate("10000110", '1');
        mii_rx_stimulate("01010110", '1');
        mii_rx_stimulate("11000110", '1');
        mii_rx_stimulate("11000110", '1');
        mii_rx_stimulate("11110110", '1');
        mii_rx_stimulate("00000010", '1');
        mii_rx_stimulate("01110111", '1');
        mii_rx_stimulate("11110110", '1');
        mii_rx_stimulate("00100111", '1');
        mii_rx_stimulate("11000110", '1');
        mii_rx_stimulate("01000110", '1');
        
        -- Padding 00
        for i in 0 to 35 loop
            mii_rx_stimulate("00000000", '1');
        end loop;
        
        -- note that each nibble is swapped.
        -- FCS F0:F4:46:3E
        mii_rx_stimulate("00001111", '1');
        mii_rx_stimulate("01001111", '1');
        mii_rx_stimulate("01100100", '1');
        mii_rx_stimulate("11100011", '1');

        -- all lines go to zero
        mii_rx_stimulate("00000000", '0');    

        -- wait for a while and then repeat        
        wait for ETHCLK_period*50;
    
    end process;
    
    
    -- simulate feeding vhdl transmitter with input
    TXDATA_process : process is
            procedure tx_stimulate(
                        data : in std_logic_vector(7 downto 0) := "XXXXXXXX";
                        en   : in std_logic                    := 'X') is
            begin
                    tx_en  <= en;
                    in_data    <= data;
                    
          
                    -- in real use, this would be handled by whatever is passing
                    -- data to the transmitter.  Most likely reading from a fifo.
                    wait for clk_period * 2;
            end procedure;        
           
        begin
        
            -- all lines go to zero
            tx_stimulate("00000000", '0');
            
            wait for ETHCLK_period*10;
           
            -- preamble
            for i in 0 to 6 loop
                tx_stimulate("01010101", '1');
            end loop; 
            
            tx_stimulate("11010101", '1');
 
            -- MAC Address FF:FF:FF:FF:FF:FF
            for i in 0 to 5 loop
                tx_stimulate("11111111", '1');
            end loop;
            
            -- MAC Address DE:AD:BE:EF:BA:5E
            tx_stimulate("11011110", '1');
            tx_stimulate("10101101", '1');
            tx_stimulate("10111110", '1');
            tx_stimulate("11101111", '1');
            tx_stimulate("10111010", '1');
            tx_stimulate("01011110", '1');
            
            -- Type BE:EF
            tx_stimulate("10111110", '1');
            tx_stimulate("11101111", '1');
            
            -- Data 68:65:6c:6c:6f:20:77:6f:72:6c:64
            tx_stimulate("01101000", '1');
            tx_stimulate("01100101", '1');
            tx_stimulate("01101100", '1');
            tx_stimulate("01101100", '1');
            tx_stimulate("01101111", '1');
            tx_stimulate("00100000", '1');
            tx_stimulate("01110111", '1');
            tx_stimulate("01101111", '1');
            tx_stimulate("01110010", '1');
            tx_stimulate("01101100", '1');
            tx_stimulate("01100100", '1');
            
            -- Padding 00
            for i in 0 to 35 loop
                tx_stimulate("00000000", '1');
            end loop;
            
            -- FCS F0:F4:46:3E
            tx_stimulate("11110000", '1');
            tx_stimulate("11110100", '1');
            tx_stimulate("01000110", '1');
            tx_stimulate("00111110", '1');
    
            -- all lines go to zero
            tx_stimulate("00000000", '0');
            
            tx_en <= '0';
            
            -- wait for a while and then repeat
            wait for ETHCLK_period*256;
        
        end process;

end Behavioral;
