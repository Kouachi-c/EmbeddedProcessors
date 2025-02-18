library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity sqrt is
    generic (
        N : integer := 32
    );
    port (
        -- Control signals
        clk : in std_logic;
        reset : in std_logic;
        start : in std_logic;
        done  : out std_logic;
 
        -- Input data
        A   : in std_logic_vector(2*N-1 downto 0);
 
        -- Output data
        S   : out std_logic_vector(N-1 downto 0)
    );
 
end entity sqrt;
 
architecture bv of sqrt is
    type state_type is (wait_state, init_state, compute_state, done_state);
    signal state : state_type := wait_state;
    signal i : natural := 0;
 
 
    begin 
 
    S_R : process(clk, reset) is
    variable D : unsigned(2*N-1 downto 0);
    variable R : signed(N+2 downto 0);
    variable Z : unsigned(N-1 downto 0);
 
 
    begin
        if reset = '1' then
            state <= wait_state;
            done <= '0';
            D := (others => '0');
            R := (others => '0');
            Z := (others => '0');
            S <= (others => '0');
            i <= 0;
 
        elsif rising_edge(clk) then
            case state is 
                when wait_state =>
                    done <= '0';
                    if start = '1' then
                        state <= init_state;
                    else
                        state <= wait_state;
                    end if;
                when init_state =>
                    done <= '0';
                    D := unsigned(A);
                    R := (others => '0');
                    Z := (others => '0');
                    S <= (others => '0');
                    i <= 0;
 
                    state <= compute_state;
 
                when compute_state =>
 
                    done <= '0';
                    if R(N+2) = '0' then 
                        R := (R sll 2) + resize(signed(D srl (2*N-2)), N+3)  - resize(signed((Z sll 2) + 1), N+3);
                    else
                        R := (R sll 2) + resize(signed(D srl (2*N-2)), N+3)  + resize(signed((Z sll 2) + 3), N+3);
                    end if;
 
                    if R(N+2) = '0' then
                        Z := resize(((Z sll 1) + 1), N);
 
                    else
                        Z := resize((Z sll 1), N);
                    end if;
                    D := resize((D sll 2), 2*N);
 
                    if i = N-1 then
						done <= '1';
						S <= std_logic_vector(Z);
                        state <= done_state;                   
                    else
                        i <= i + 1;
                    end if;
 
                when done_state =>
				
                    done <= '1';
                    if start = '1' then
                        state <= done_state;
                    else
                        state <= wait_state;
                    end if;
 
                when others =>
                    state <= wait_state;
            end case;
 
        end if;
    end process S_R;
 
end architecture bv;