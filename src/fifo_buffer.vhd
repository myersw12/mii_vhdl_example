----------------------------------------------------------------------------------
-- Module Name: fifo_buffer - Behavioral
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
-- Heavily referenced:
-- http://www.asic-world.com/examples/vhdl/asyn_fifo.html
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity fifo_buffer is

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
    
end fifo_buffer;

architecture rtl of fifo_buffer is
        
    component ram is
    port(
        write_en : in std_logic;
        waddr : in std_logic_vector (addr_width - 1 downto 0);
        wclk : in std_logic;
        raddr : in std_logic_vector (addr_width - 1 downto 0);
        rclk : in std_logic;
        din : in std_logic_vector (data_width - 1 downto 0);
        dout : out std_logic_vector (data_width - 1 downto 0));
    end component;
    
    component gray_counter is
    generic (
        counter_width : integer := 11
    );
    Port ( graycount_out    : out STD_LOGIC_VECTOR (counter_width-1 downto 0);
           enable           : in STD_LOGIC;
           clear            : in STD_LOGIC;
           clk              : in STD_LOGIC);
    end component;
    
    signal pNextWordToWrite     :std_logic_vector (ADDR_WIDTH-1 downto 0);
    signal pNextWordToRead      :std_logic_vector (ADDR_WIDTH-1 downto 0);
    signal EqualAddresses       :std_logic;
    signal NextWriteAddressEn   :std_logic;
    signal NextReadAddressEn    :std_logic;
    signal Set_Status           :std_logic;
    signal Rst_Status           :std_logic;
    signal Status               :std_logic;
    signal PresetFull           :std_logic;
    signal PresetEmpty          :std_logic;
    signal empty,full           :std_logic;

begin
    
    -- Fifo address support logic
    -- 'NextAddresses' enable logic    
    NextWriteAddressEn <= write and (not full);
    NextReadAddressEn <= read and (not empty);
    
    -- BRAM setup
    ram_inst: ram port map(
        write_en => write,
        waddr => pNextWordToWrite,
        wclk => wclk,
        raddr => pNextWordToRead,
        rclk => rclk,
        din => write_data,
        dout => read_data
          );
          
    --Addreses (Gray counters) logic:
    GrayCounter_pWr : gray_counter
    port map (
      GrayCount_out => pNextWordToWrite,
      enable        => NextWriteAddressEn,
      clear         => reset,
      clk           => WClk
    );
     
    GrayCounter_pRd : gray_counter
    port map (
      GrayCount_out => pNextWordToRead,
      enable        => NextReadAddressEn,
      clear         => reset,
      clk           => RClk
    );
    
    -- 'Equal addresses' logic
    EqualAddresses <= '1' when (pNextWordToWrite = pNextWordToRead) else '0';
    
    -- 'Quadrant Selectors' Logic
    process (pNextWordToWrite, pNextWordToRead)
        variable set_status_bit0 :std_logic;
        variable set_status_bit1 :std_logic;
        variable rst_status_bit0 :std_logic;
        variable rst_status_bit1 :std_logic;
    begin
        set_status_bit0 := pNextWordToWrite(addr_width-2) xnor pNextWordToRead(addr_width-1);
        set_status_bit1 := pNextWordToWrite(addr_width-1) xor  pNextWordToRead(addr_width-2);
        Set_Status <= set_status_bit0 and set_status_bit1;
        
        rst_status_bit0 := pNextWordToWrite(addr_width-2) xor  pNextWordToRead(addr_width-1);
        rst_status_bit1 := pNextWordToWrite(addr_width-1) xnor pNextWordToRead(addr_width-2);
        Rst_Status      <= rst_status_bit0 and rst_status_bit1;
    end process;
    
    --'Status' latch logic:
    process (Set_Status, Rst_Status, reset) begin--D Latch w/ Asynchronous Clear & Preset.
        if (Rst_Status = '1' or reset = '1') then
            Status <= '0';  --Going 'Empty'.
        elsif (Set_Status = '1') then
            Status <= '1';  --Going 'Full'.
        end if;
    end process;
    
    --'Full_out' logic for the writing port:
    PresetFull <= Status and EqualAddresses;  --'Full' Fifo.
    
    process (wclk, PresetFull) begin --D Flip-Flop w/ Asynchronous Preset.
        if (PresetFull = '1') then
            full <= '1';
        elsif (rising_edge(wclk)) then
            full <= '0';
        end if;
    end process;
    
    Full_out <= full;
    
    --'Empty_out' logic for the reading port:
    PresetEmpty <= not Status and EqualAddresses;  --'Empty' Fifo.
    
    process (rclk, PresetEmpty) begin --D Flip-Flop w/ Asynchronous Preset.
        if (PresetEmpty = '1') then
            empty <= '1';
        elsif (rising_edge(rclk)) then
            empty <= '0';
        end if;
    end process;
    
    Empty_out <= empty;
    
   
end rtl;
