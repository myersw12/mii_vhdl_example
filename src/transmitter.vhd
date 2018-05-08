-------------------------------------------------------------------------------
-- transmitter
-- ------------
-- converts 8 bit transmit data to 4 bit transmit data
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity transmitter is
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
end entity transmitter;


architecture transmit of transmitter is
	type stateType is	(idle, send_low, send_high);
	signal state : stateType;
	signal count : std_logic_vector(3 downto 0);
begin

-- This is a really simple transmitter.  It does not add the preamble on it's own.
-- Data should be presented at an interval of ETHCLK_period * 2 so that is has time to
-- send 2 nibbles without having to buffer anything.

unpack : process(clk)
begin
	if rising_edge(clk) then
		if clr = '1' then
			state <= idle;
		else
			case state is
				when idle =>
					count <= "0000";
					if txen_8 = '1' then
						state <= send_low;
					end if;
					
				when send_low =>
					if txen_8 = '1' then
						state <= send_high;
					else 
						state <= idle;
					end if;

				when send_high =>
					state <= send_low;

			end case;
		end if; -- clr
	end if; -- clk
end process unpack;

with state select
	txen_4 <=	'0' when idle,
						txen_8 when others;

with state select
	txdata_4 <= txdata_8(3 downto 0) when send_low,
				txdata_8(7 downto 4) when send_high,
				"0000" when idle;

end architecture transmit;
