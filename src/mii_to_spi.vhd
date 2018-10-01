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

entity mii_to_spi is
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
           
           read_enable  : out std_logic;
           write_enable : in std_logic  
         );
end mii_to_spi;

architecture rtl of mii_to_spi is

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
    
    component ram is
    generic (
        addr_width : natural := 11;--2048x8
        data_width : natural := 8);
    port(
        rst     : in std_logic;
        write_en : in std_logic;
        waddr : in std_logic_vector (addr_width - 1 downto 0);
        wclk : in std_logic;
        raddr : in std_logic_vector (addr_width - 1 downto 0);
        rclk : in std_logic;
        din : in std_logic_vector (data_width - 1 downto 0);
        dout : out std_logic_vector (data_width - 1 downto 0));
    end component;    

    signal mii_rx_data          : std_logic_vector(7 downto 0) := (others => '0');
    signal mii_tx_data          : std_logic_vector(7 downto 0) := (others => '0');
    signal mii_rx_valid         : std_logic := '0';
    signal mii_tx_enable        : std_logic := '0';
    signal mii_read_fifo        : std_logic := '0';
    
    signal rx_pkt_len           : std_logic_vector(10 downto 0) := (others => '0');
    signal rx_pkt_done          : std_logic := '0';
   
    -- this counter needs to go up to 4 
    signal byte_counter         : std_logic_vector(1 downto 0) := (others => '0');
    -- get this from header
    signal read_or_write        : std_logic := '0';
    signal destination          : std_logic_vector(1 downto 0) := (others => '0');
    signal addr_upper           : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_lower           : std_logic_vector(7 downto 0) := (others => '0');
    signal address              : std_logic_vector(15 downto 0) := (others => '0');
    signal data_byte            : std_logic_vector(7 downto 0) := (others => '0');
    
    
    signal tx_we                : std_logic := '0';
    signal tx_write_addr        : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0'); 
    signal tx_read_addr         : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0'); 
    signal tx_data_in           : std_logic_vector (ram_data_width - 1 downto 0) := (others => '0'); 
    signal tx_data_out          : std_logic_vector (ram_data_width - 1 downto 0) := (others => '0');    
    
    signal rx_we                : std_logic := '0';
    signal rx_write_addr        : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0'); 
    signal rx_read_addr         : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0'); 
    signal rx_data_in           : std_logic_vector (ram_data_width - 1 downto 0) := (others => '0'); 
    signal rx_data_out          : std_logic_vector (ram_data_width - 1 downto 0) := (others => '0'); 
    
    signal reg_we               : std_logic := '0';
    signal reg_write_addr       : std_logic_vector (7 downto 0) := (others => '0'); 
    signal reg_read_addr        : std_logic_vector (7 downto 0) := (others => '0'); 
    signal reg_data_in          : std_logic_vector (7 downto 0) := (others => '0'); 
    signal reg_data_out         : std_logic_vector (7 downto 0) := (others => '0'); 
    
    type state_type is (idle, process_data);
    signal state : state_type;
    
    -- Command Register Addresses
    -- 0x00 - RX Read pointer upper
    -- 0x01 - RX Read pointer lower
    -- 0x02 - RX Write pointer upper
    -- 0x03 - RX Write pointer lower
    -- 0x04 - RX received size upper
    -- 0x05 - RX received size lower
    -- 0x06 - TX Read pointer upper
    -- 0x07 - TX Read pointer lower
    -- 0x08 - TX Write pointer upper
    -- 0x09 - TX Write pointer lower
    -- 0x0A - TX Free size upper
    -- 0x0B - TX Free size lower
    -- 0x0C - Command Register
    
    signal rx_read_pointer      : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0');
    signal rx_write_pointer     : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0');
    signal rx_received_size     : std_logic_vector (15 downto 0) := (others => '0');
    signal tx_read_pointer      : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0');
    signal tx_write_pointer     : std_logic_vector (ram_addr_width - 1 downto 0) := (others => '0');
    signal tx_free_size         : std_logic_vector (15 downto 0) := (others => '0');
    signal command              : std_logic_vector (7 downto 0) := (others => '0');



begin

    ethernet: ethernet_top
        port map (
            -- MII signals
            rxclk       => mii_rx_clk,
            txclk       => mii_tx_clk,
            rxdata_4    => rxdata_4,
            rxdv_4      => rxdv_4,
            txdata_4    => txdata_4,
            txen_4      => txen_4,
            col         => col,
            drop        => drop,
            reset       => rst,
            -- Ram signals
            rxdata      => mii_rx_data,
            rxdv        => mii_rx_valid,
            txdata      => mii_tx_data,
            txen        => mii_read_fifo,
            rx_pkt_len_out => rx_pkt_len,
            rx_pkt_done => rx_pkt_done
        );
        
    tx_ram : ram
        generic map (
            addr_width => ram_addr_width,
            data_width => ram_data_width
        )
        port map (
            rst => rst,
            write_en => tx_we,
            waddr => tx_write_addr,
            wclk => clk,
            raddr => tx_read_addr,
            rclk => mii_tx_clk,
            din => tx_data_in,
            dout => tx_data_out
        );
        
    rx_ram : ram
        generic map (
            addr_width => ram_addr_width,
            data_width => ram_data_width
        )
        port map (
            rst => rst,
            write_en => rx_we,
            waddr => rx_write_addr,
            wclk => mii_rx_clk,
            raddr => rx_read_addr,
            rclk => clk,
            din => rx_data_in,
            dout => rx_data_out
        );
        
    -- Message Structure
    -- 4 bytes
    -- 0 - Header
    -- 1 - Addr Upper
    -- 2 - Addr Lower
    -- 3 - Data
    
    -- Header
    -- 0 - read / write (0, 1)
    -- 1 - dest upper
    -- 2 - dest lower
    -- 3 - open
    -- 4 - open
    -- 5 - open
    -- 6 - open
    -- 7 - open
    
    -- dest
    -- 00 - rx ram
    -- 01 - tx ram
    -- 11 - reg ram 
    
    -- Command Register Addresses
    -- 0x00 - RX Read pointer upper
    -- 0x01 - RX Read pointer lower
    -- 0x02 - RX Write pointer upper
    -- 0x03 - RX Write pointer lower
    -- 0x04 - RX received size upper
    -- 0x05 - RX received size lower
    -- 0x06 - TX Read pointer upper
    -- 0x07 - TX Read pointer lower
    -- 0x08 - TX Write pointer upper
    -- 0x09 - TX Write pointer lower
    -- 0x0A - TX Free size upper
    -- 0x0B - TX Free size lower
    -- 0x0C - Command Register
    
    register_ram : ram
        generic map (
            addr_width => 8,
            data_width => 8
        )
        port map (
            rst => rst,
            write_en => reg_we,
            waddr => reg_write_addr,
            wclk => clk,
            raddr => reg_read_addr,
            rclk => clk,
            din => reg_data_in,
            dout => reg_data_out
        );
    
    state_proc : process(clk, rst) begin
        if (rst = '1') then
            state <= idle;
        elsif rising_edge(clk) then

            case state is
                -- if we are waiting and in_data has something, then we are at the start of a 
                -- 4 byte transaction
                when idle => 
                    if in_data /= "00000000" then
                        state <= process_data;
                    end if;
                -- process remainder of packet
                when process_data =>
                    -- if the byte counter hits 4, we are done with this transaction
                    if byte_counter = "11" then
                        state <= idle;
                    end if;
            end case;
        end if;
    end process state_proc;
    
    reg_proc : process(clk, rst) begin
        if (rst = '1') then
            byte_counter <= (others => '0');
            read_or_write <= '0';
            destination <= (others => '0');
            addr_upper <= (others => '0');
            address <= (others => '0');
        elsif (rising_edge(clk)) then
        
            if state = process_data then
            
                -- first byte, get info from the header
                if byte_counter = "00" then
                    read_or_write <= in_data(0);
                    destination <= in_data(1) & in_data(2);
                -- second byte, upper part of the address
                elsif byte_counter = "01" then
                    addr_upper <= in_data;
                -- third byte, lower part of the address
                elsif byte_counter = "10" then
                    address <= addr_upper & in_data;
                --fourth byte, data. 
                elsif byte_counter = "11" then
                    data_byte <= in_data;
                end if;
            
            -- increment the counter
            byte_counter <= std_logic_vector(unsigned(byte_counter) + 1);
            elsif state = idle then
                -- when idle, keep the counter at 0
                byte_counter <= "00";
            end if;
        end if;
        
    
    end process reg_proc;
    
    -- This process sets the read address for the external interface and
    -- handles writes from the mii receiver.
    rx_ram_proc : process(clk, mii_rx_clk) begin
        if (rst = '1') then
            rx_read_addr <= (others => '0');
        -- update the read address if it is the end of a transaction
        elsif rising_edge(clk) then
            if byte_counter = "11" and destination = "00" then
                -- read from rx_ram
                if read_or_write = '0' then
                    rx_read_addr <= address(ram_addr_width - 1 downto 0);
                    rx_read_pointer <= address(ram_addr_width -1 downto 0);
                end if;
                
                if rx_read_pointer = rx_write_pointer then
                    rx_received_size <= (others => '0');
                end if;
            end if;
        
        -- if we have mii data, write it to memory.  Update the write pointer,
        -- the read pointer is updated during the read.
        elsif rising_edge(mii_rx_clk) then
            -- if there is valid data, start writing to ram
            if (mii_rx_valid = '1') then    
                rx_we <= '1';
                rx_write_addr <= rx_write_pointer;
                -- increment rx_write pointer, wrap around if necessary
                if (rx_write_pointer = "11111111111") then
                    rx_write_pointer <= (others => '0');
                else
                    rx_write_pointer <= std_logic_vector(unsigned(rx_write_pointer) + 1);
                end if;           
            else
                rx_we <= '0';
            end if;
            
            if (rx_pkt_done = '1') then
                rx_received_size <= std_logic_vector(unsigned(rx_received_size) + unsigned(rx_pkt_len));
            end if;
            
        end if;
    end process rx_ram_proc;

    tx_ram_proc : process(clk, mii_tx_clk) begin
        if (rst = '1') then
            tx_we <= '0';
            tx_write_addr <= (others => '0');
            tx_data_in <= (others => '0');
            tx_read_addr <= (others => '0');
        elsif rising_edge(clk) then
            if byte_counter = "11" and destination = "01" then
                -- write to tx ram
                if read_or_write = '1' then
                    tx_we <= '1';
                    tx_write_addr <= address(ram_addr_width - 1 downto 0);
                    tx_write_pointer <= address(ram_addr_width - 1 downto 0);
                    tx_data_in <= data_byte;
                end if;
            else
                tx_we <= '0';
            end if;
            
        elsif rising_edge(mii_tx_clk) then
            if (command = x"C0") then
                if (tx_read_pointer /= tx_write_pointer) then
                    tx_read_addr <= tx_read_pointer;
                    -- increment the read pointer and wrap around if necessary
                    if (tx_read_pointer = "11111111111") then
                        tx_read_pointer <= (others => '0');
                    else
                        tx_read_pointer <= std_logic_vector(unsigned(tx_read_pointer) + 1);
                    end if;
                else
                    command <= x"00";
                end if;
            end if;
        end if;
    
    end process tx_ram_proc;
    
    reg_ram_proc : process(clk) begin
        if (rst = '1') then
            reg_we <= '0';
            reg_write_addr <= (others => '0');
            reg_data_in <= (others => '0');
            reg_read_addr <= (others => '0');
        elsif rising_edge(clk) then
            if byte_counter = "11" and destination = "11" then
                -- write to reg ram
                if read_or_write = '1' then
                    reg_we <= '1';
                    reg_write_addr <= address(7 downto 0);
                    reg_data_in <= data_byte;
                -- read from reg_ram
                else 
                    reg_read_addr <= address(7 downto 0);
                end if;
            else
                reg_we <= '0';
            end if;
        end if;
    
    end process reg_ram_proc;
    
    out_data_mux : process (clk, rst) begin
        if (rst = '1') then
            out_data <= (others => '0');
        elsif rising_edge(clk) then
            -- if this is the end of a transaction, we might need to change the output
            if byte_counter = "11" then
                -- if we are doing a read, we need to know
                -- which ram we are reading from and change the output 
                -- accordingly
                if read_or_write = '0' then
                    case destination is 
                        -- rx ram
                        when "00" => 
                            out_data <= rx_data_out;
                        -- tx ram
                        when "01" =>
                            out_data <= tx_data_out;
                        -- register ram
                        when "11" =>
                            out_data <= reg_data_out;
                        when others =>
                            out_data <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process out_data_mux;



end rtl;
