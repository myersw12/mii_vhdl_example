library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity ram is
generic (
    addr_width : natural := 11;--2048x8
    data_width : natural := 8);
port (
    rst : in std_logic;
    write_en : in std_logic;
    waddr : in std_logic_vector (addr_width - 1 downto 0);
    wclk : in std_logic;
    raddr : in std_logic_vector (addr_width - 1 downto 0);
    rclk : in std_logic;
    din : in std_logic_vector (data_width - 1 downto 0);
    dout : out std_logic_vector (data_width - 1 downto 0));
end ram;

architecture rtl of ram is
    type mem_type is array ((2** addr_width) - 1 downto 0) of
        std_logic_vector(data_width - 1 downto 0);
    signal mem : mem_type := (others => (others => '0'));

begin
    process (wclk, rst)
    -- Write memory.
    begin
        if (rst = '1') then
            mem <= (others => (others => '0'));
        elsif (wclk'event and wclk = '1') then
            if (write_en = '1') then
                mem(conv_integer(waddr)) <= din;
                -- Using write address bus.
            end if;
        end if;
    end process;
    
    process (rclk) -- Read memory.
    begin
        if (rclk'event and rclk = '1') then
            dout <= mem(conv_integer(raddr));
            -- Using read address bus.
        end if;
    end process;
end rtl;
