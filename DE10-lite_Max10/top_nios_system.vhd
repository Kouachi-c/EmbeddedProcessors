library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_nios_system is
    port(
        CLOCK_50 : in std_logic; 
        KEY : in std_logic_vector(1 downto 0);

        SW : in std_logic_vector(9 downto 0);

        LEDR : out std_logic_vector(9 downto 0);

        HEX0 : out std_logic_vector(7 downto 0);
        HEX1 : out std_logic_vector(7 downto 0);
        HEX2 : out std_logic_vector(7 downto 0);
        HEX3 : out std_logic_vector(7 downto 0)



    );
end top_nios_system;

architecture top_nios_system_rtl of top_nios_system is 

    ------------------------------------------------------------
    --+              NIOS_SYSTEM COMPONENT                   +--
    ------------------------------------------------------------
	component nios_system is
		port (
			clk_clk       : in  std_logic                    := 'X';             -- clk
			hex0_export   : out std_logic_vector(7 downto 0);                    -- export
			hex1_export   : out std_logic_vector(7 downto 0);                    -- export
			hex2_export   : out std_logic_vector(7 downto 0);                    -- export
			hex3_export   : out std_logic_vector(7 downto 0);                    -- export
			ledr_export   : out std_logic_vector(9 downto 0);                    -- export
			sw_export     : in  std_logic_vector(9 downto 0) := (others => 'X'); -- export
			reset_reset_n : in  std_logic                    := 'X'              -- reset_n
		);
	end component nios_system;


	begin

	u0 : component nios_system
		port map (
			clk_clk       => CLOCK_50,       --   clk.clk
			hex0_export   => HEX0,   			--  hex0.export
			hex1_export   => HEX1,   			--  hex1.export
			hex2_export   => HEX2,  		 	--  hex2.export
			hex3_export   => HEX3,   			--  hex3.export
			ledr_export   => LEDR,   			--  ledr.export
			sw_export     => SW,     			--    sw.export
			reset_reset_n => KEY(1)  			-- reset.reset_n
		);




end architecture top_nios_system_rtl;