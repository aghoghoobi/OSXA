----------------------------------------------------------------------
----                                                              ----
---- LPC PERIPHERAL INTERFACE FOR LPC FLASH DEVICES               ----
----                                                              ----
---- lpc_device.vhd                                               ----
----                                                              ----
----                                                              ----
---- Description:                                                 ----
---- Translate the addressing scheme between an LPC host and an   ----
---- LPC peripheral. At the moment, it only supports LPC Memory   ----
---- Read/Write between an LPC host and the follwing LPC flash    ----
---- devices:							  ----
----      SST49LF020                                              ----
----      SST49LF020A                                             ----
----      SST49LF080A                                             ----
----      SST49LF160C                                             ----
----                                                              ----
---- Author(s):                                                   ----
----     - Aghogho Obi, one_eyed_monk on ASSEMBLERGAMES.COM       ----
----                                                              ----
----------------------------------------------------------------------
----                                                              ----
---- Copyright (C) 2017 Aghogho Obi                               ----
----                                                              ----
---- This source file may be used and distributed without         ----
---- restriction provided that this copyright statement is not    ----
---- removed from the file and that any derivative work contains  ----
---- the original copyright notice and the associated disclaimer. ----
----                                                              ----
---- This source code is free software: you can redistribute it   ----
---- and/or modify it under the terms of the GNU General Public   ----
---- License as published by the Free Software Foundation,either  ----
---- version 3 of the License, or (at your option) any later      ----
---- version.                                                     ----
----                                                              ----
---- This source is distributed in the hope that it will be       ----
---- useful, but WITHOUT ANY WARRANTY; without even the implied   ----
---- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ----
---- PURPOSE. See the GNU General Public License for more         ----
---- details.                                                     ----
----                                                              ----
---- You should have received a copy of the GNU General Public    ----
---- License along with this source; if not, download and see it  ----
---- from <http://www.gnu.org/licenses/>                          ----
----                                                              ----
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity lpc_device is

port
( 
	LCLK_i 	: in std_logic ;
	LCLK_o 	: out std_logic ;
	LRST_i 	: in std_logic ;
	LRST_o 	: out std_logic ;
	LFRAME_o: out std_logic ;
	SW_i 	: in std_logic_vector (2 downto 0);
	LAD_i	: inout std_logic_vector (3 downto 0);
	LAD_o	: inout std_logic_vector (3 downto 0)
);

end;

architecture lpc_device_arch of lpc_device is

	-- LPC BUS STATES for memory IO. Will need to include other states to
	-- support other LPC transactions. 
type LPC_TYPE is 
(
	START, 
	CYCTYPE_DIR, 
	ADDR1, 
	ADDR2, 
	ADDR3, 
	ADDR4, 
	ADDR5, 
	ADDR6, 
	ADDR7, 
	ADDR8, 
	TAR1, 
	TAR2, 
	SYNC, 
	DATA1, 
	DATA2, 
	DATA3,
	DATA4,
	TAR3, 
	TAR4
);

signal LPC_STATE	: LPC_TYPE 	:= START;
signal LAD_i_o		: std_logic_vector ( 3 downto 0 );
signal LAD_o_o		: std_logic_vector ( 3 downto 0 );
signal rRW		: STD_LOGIC := '0';

begin
	-- Pass on the clock and reset signals from the XBOX LPC to the flash device
	LCLK_o <= LCLK_i;
	LRST_o <= LRST_i;

	-- Generate the required LFRAME signal 
	LFRAME_o <= '0' when ((LAD_i = "0000") AND (LPC_STATE = START)) else '1';

	-- Control the IO direction of the bidirectional ports 
	LAD_i <= LAD_i_o when ((LPC_STATE = SYNC) or (LPC_STATE = DATA1) or 
			(LPC_STATE = DATA2) or (LPC_STATE = TAR3)) else "ZZZZ";

	LAD_o <= "ZZZZ" when ((LPC_STATE = TAR2) or (LPC_STATE = SYNC) or 
			(LPC_STATE = DATA1) or (LPC_STATE = DATA2) or 
			(LPC_STATE = TAR3) or (LPC_STATE = TAR4)) else LAD_o_o;

	-- Provide the connection from the LPC FLASH to the LPC BUS 
	LAD_i_o <= LAD_o;
	
	-- Generate the required addressing scheme for the LPC flash device.
	-- This addressing scheme supports the following devices if pullup on SW_i is enabled:
	-- SST49LF020, SST49LF020A, SST49LF080A and SST49LF160C
	-- See the datasheet for the LPC flash device if you want to change this.
	LAD_o_o <= "111" & SW_i(2) when (LPC_STATE = ADDR3) else
		   SW_i(1 downto 0) & LAD_i(1 downto 0) when (LPC_STATE = ADDR4) else
		   LAD_i;

	-- LPC Device State machine, see the Intel LPC Specifications for details
	process(LRST_i, LCLK_i)
	begin
		if (LRST_i = '0') then

			rRW <= '0';
			LPC_STATE <= START;

		elsif rising_edge(LCLK_i) then

			case LPC_STATE is
			
				when START =>

					if LAD_i = "0000" then
						LPC_STATE <= CYCTYPE_DIR;
					end if;
				
				when CYCTYPE_DIR =>

					if LAD_i(3 downto 2) = "01" then
						rRW <= LAD_i(1);
						LPC_STATE <= ADDR1;
					else
						LPC_STATE <= START;
					end if;				
										
				when ADDR1 =>

					LPC_STATE <= ADDR2;
							
				when ADDR2 =>	
			
					LPC_STATE <= ADDR3;
					
				when ADDR3 =>	
			
					LPC_STATE <= ADDR4;
					
				when ADDR4 =>	
			
					LPC_STATE <= ADDR5;
					
				when ADDR5 =>	
			
					LPC_STATE <= ADDR6;
					
				when ADDR6 =>	
			
					LPC_STATE <= ADDR7;
					
				when ADDR7 =>
				
					LPC_STATE <= ADDR8;
					
				when ADDR8 =>
					
					if rRW = '0' then
						LPC_STATE <= TAR1;
					else
						LPC_STATE <= DATA3;
					end if;
					
				when TAR1 =>

					LPC_STATE <= TAR2;
					
				when TAR2 =>
						
					LPC_STATE <= SYNC;
					
				when SYNC =>

					if rRW = '0' then
						LPC_STATE <= DATA1;
					else
						LPC_STATE <= TAR3;
					end if;

				when DATA1 =>	

					LPC_STATE <= DATA2;
					
				when DATA2 =>

					LPC_STATE <= TAR3;

				when DATA3 =>
				
					LPC_STATE <= DATA4;
				
				when DATA4 =>

					LPC_STATE <= TAR1;
					
				when TAR3 =>

					LPC_STATE <= TAR4;
					
				when TAR4 =>
					
					LPC_STATE <= START;
				
			end case;
		end if;
	end process;

end lpc_device_arch;


