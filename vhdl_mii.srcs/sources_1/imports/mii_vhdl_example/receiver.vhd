-- receiver
-- ---------
-- Converts 4 bit rx signal to 8 bit, data is ready every second clock cycle
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity receiver is
	port (
		
		clk:										in std_logic;
		clr:										in std_logic;
		
		-- from MII
		rxdata_4:								in std_logic_vector(3 downto 0);
		rxdv_4:									in std_logic;
		
		-- to output
		rxdata_8:								out std_logic_vector(7 downto 0);
		rxdv_8:									out std_logic
	);
end entity receiver;


architecture receive of receiver is
	type stateType is (idle, low, high);
	signal state : stateType;
	signal rxlow, rxhigh:		std_logic_vector(3 downto 0);
	signal count :              std_logic := '0';
	signal burst_started :      std_logic := '0'; 
begin

-- Looking at an ethernet frame on paper, the bytes are sent
-- in left to right, top to bottom fashion.
-- within each byte, the LSNibble is sent first, then the
-- MSNibble.  So, put the first nibble in the lower 4 bits
-- of the byte, and the next in the higher bits.

pack : process(clk)
begin
	if rising_edge(clk) then
		if clr = '1' then
			state <= idle;
			count <= '0'; -- even and odd, used for rxdv_8 signal
		    burst_started <= '0';
		else
			case state is
				when idle =>
					-- Wait for the start of frame delimiter, ignore it
					-- sfd is 1101 in big endian format
					if rxdata_4(3) = '1' and rxdv_4 = '1' then
						state <= low;
						count <= '1';
					else
					    burst_started <= '0';
					end if;

				when low =>
					if rxdv_4 = '1' then
						state <= high;
						count <= not count;
					else
						state <= idle;	-- end of frame
					end if;

				when high =>
					if rxdv_4 = '1' then
						state <= low;
						count <= not count;
					else
						state <= idle;	-- shouldn't ever happen
					end if;

			end case;
			
			if count = '1' then
			    -- combine rxhigh and rxlow to make 1 byte of data
                rxdata_8 <= rxhigh & rxlow;
                burst_started <= '1';
                count <= '0';
            end if;
            
		end if; -- clr
	end if; -- clk
end process pack;

data_out : process(clk)
begin

    if rising_edge(clk) then
        -- produce a rising edge on rxdv_8 every time data is ready to be read
        if count = '1' and (burst_started = '1') then
            rxdv_8 <= '1';
        else
            rxdv_8 <= '0';
        end if;
        -- load data from MII into rxlow and rxhigh
        if (state = low) then
            rxlow <= rxdata_4;
        else
            rxlow <= rxlow;
        end if;
        if (state = high) then
            rxhigh <= rxdata_4;
        else
            rxhigh <= rxhigh;
        end if;
    
    end if;

end process data_out;

end architecture receive;

