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

	u0 : component nios_system
		port map (
			clk_clk       => CONNECTED_TO_clk_clk,       --   clk.clk
			hex0_export   => CONNECTED_TO_hex0_export,   --  hex0.export
			hex1_export   => CONNECTED_TO_hex1_export,   --  hex1.export
			hex2_export   => CONNECTED_TO_hex2_export,   --  hex2.export
			hex3_export   => CONNECTED_TO_hex3_export,   --  hex3.export
			ledr_export   => CONNECTED_TO_ledr_export,   --  ledr.export
			sw_export     => CONNECTED_TO_sw_export,     --    sw.export
			reset_reset_n => CONNECTED_TO_reset_reset_n  -- reset.reset_n
		);

