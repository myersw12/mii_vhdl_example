----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/04/2018 08:45:59 PM
-- Design Name: 
-- Module Name: gray_coder - Behavioral
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity gray_counter is
    generic (
        counter_width : integer := 11
    );
    Port ( graycount_out    : out STD_LOGIC_VECTOR (counter_width-1 downto 0);
           enable           : in STD_LOGIC;
           clear            : in STD_LOGIC;
           clk              : in STD_LOGIC);
end gray_counter;

architecture rtl of gray_counter is
    signal binary_count : std_logic_vector (counter_width -1 downto 0);
begin

    process(clk) begin
        if (rising_edge(clk)) then
            if (clear = '1') then
                -- Gray count begins at '1' with
                binary_count <= conv_std_logic_vector(1, counter_width);
                graycount_out <= (others => '0');
            -- first enable in
            elsif (enable = '1') then
                binary_count <= binary_count + 1;
                graycount_out <= (binary_count(counter_width -1) &
                                  (binary_count(counter_width -2 downto 0) xor
                                  binary_count(counter_width -1 downto 1)));
            end if;
        end if;
    end process;
end architecture;
