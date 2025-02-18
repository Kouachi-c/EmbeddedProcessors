library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdram_controller is
    port (
        -- Clocks & Reset
        clk         : in  std_logic;  -- Horloge système
        reset_n     : in  std_logic;  -- Reset asynchrone actif bas

        -- Interface utilisateur (simplifiée)
        -- Pour l'exemple, on suppose un bus interne pour demander lecture/écriture
        user_addr   : in  std_logic_vector(23 downto 0);  -- Adresse logique (row/bank/col combinés)
        user_data_in: in  std_logic_vector(15 downto 0);
        user_data_out: out std_logic_vector(15 downto 0);
        user_we     : in  std_logic;  -- 1 = demande d'écriture
        user_re     : in  std_logic;  -- 1 = demande de lecture
        user_ack    : out std_logic;  -- Accusé de réception (opération terminée)

        -- Interface SDRAM
        DRAM_DQ     : inout std_logic_vector(15 downto 0);
        DRAM_ADDR   : out std_logic_vector(12 downto 0);
        DRAM_BA     : out std_logic_vector(1 downto 0);
        DRAM_CLK    : out std_logic;  -- Horloge SDRAM (souvent le même que clk ou un PLL)
        DRAM_CKE    : out std_logic;
        DRAM_CS_N   : out std_logic;
        DRAM_RAS_N  : out std_logic;
        DRAM_CAS_N  : out std_logic;
        DRAM_WE_N   : out std_logic;
        DRAM_LDQM   : out std_logic;
        DRAM_UDQM   : out std_logic
    );
end sdram_controller;

architecture RTL of sdram_controller is

    ----------------------------------------------------------------
    -- Déclaration des types/constantes pour la machine d’état
    ----------------------------------------------------------------
    type state_type is (
        st_reset,
        st_init_precharge_all,
        st_init_refresh_1,
        st_init_refresh_2,
        st_init_load_mode,
        st_idle,
        st_activate,
        st_read,
        st_write,
        st_precharge,
        st_refresh
    );
    signal current_state, next_state : state_type;

    -- Constantes de temporisation (à adapter selon la datasheet SDRAM)
    constant tRP      : integer := 3;   -- Precharge time en cycles
    constant tRFC     : integer := 7;   -- Refresh time en cycles
    constant tMRD     : integer := 2;   -- Load Mode Register to next command
    constant tRCD     : integer := 3;   -- Row to column delay
    constant tCAS     : integer := 2;   -- CAS latency (ex: 2 ou 3)

    ----------------------------------------------------------------
    -- Compteurs divers pour gérer les délais
    ----------------------------------------------------------------
    signal timer       : integer range 0 to 255 := 0;
    signal refresh_cnt : integer range 0 to 4095 := 0;  -- Pour compter quand faire un refresh

    ----------------------------------------------------------------
    -- Signaux internes pour DRAM_DQ (direction)
    ----------------------------------------------------------------
    signal dq_out    : std_logic_vector(15 downto 0) := (others => '0');
    signal dq_oe     : std_logic := '0';  -- 1 = sortie active vers SDRAM

    ----------------------------------------------------------------
    -- Assignation des sorties
    ----------------------------------------------------------------
    -- On assigne DRAM_CLK = clk dans cet exemple simplifié (pas de phase shift)
    begin
    DRAM_CLK <= clk;

    -- Pilotage du bus de données bidirectionnel
    with dq_oe select
        DRAM_DQ <= dq_out when '1',
                    (others => 'Z') when others;

    -- Exemple simple de signaux de commande (générés plus bas dans la FSM)
    ----------------------------------------------------------------

    ----------------------------------------------------------------
    -- Machine d’état principale
    ----------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            current_state <= st_reset;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Gestion du timer, refresh, etc.
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            timer <= 0;
            refresh_cnt <= 0;
        elsif rising_edge(clk) then
            if timer > 0 then
                timer <= timer - 1;
            end if;
            -- Exemple : incrémenter un compteur de refresh
            if refresh_cnt = 780 then
                -- ~ tous les 7.8µs si clk=100 MHz, c’est à affiner
                refresh_cnt <= 0;
            else
                refresh_cnt <= refresh_cnt + 1;
            end if;
        end if;
    end process;

    -- Prochain état et commandes
    process(current_state, user_we, user_re, timer, refresh_cnt)
    begin
        -- Valeurs par défaut
        next_state <= current_state;

        case current_state is

            ----------------------------------------------------------------
            -- 1) Reset
            ----------------------------------------------------------------
            when st_reset =>
                -- On attend que tout soit stable
                next_state <= st_init_precharge_all;

            ----------------------------------------------------------------
            -- 2) Init : Precharge All
            ----------------------------------------------------------------
            when st_init_precharge_all =>
                -- Envoyer commande Precharge All
                -- RAS=0, CAS=1, WE=0, BA=xx, A10=1 => Precharge All
                if timer = 0 then
                    -- Démarrer le timer pour tRP
                    next_state <= st_init_refresh_1;
                end if;

            ----------------------------------------------------------------
            -- 3) Init : Auto-Refresh 1
            ----------------------------------------------------------------
            when st_init_refresh_1 =>
                -- Envoyer commande Auto-Refresh (RAS=0, CAS=0, WE=1)
                if timer = 0 then
                    -- Démarrer le timer pour tRFC
                    next_state <= st_init_refresh_2;
                end if;

            ----------------------------------------------------------------
            -- 4) Init : Auto-Refresh 2
            ----------------------------------------------------------------
            when st_init_refresh_2 =>
                -- Même chose que refresh_1
                if timer = 0 then
                    -- Démarrer le timer pour tRFC
                    next_state <= st_init_load_mode;
                end if;

            ----------------------------------------------------------------
            -- 5) Init : Load Mode Register
            ----------------------------------------------------------------
            when st_init_load_mode =>
                -- Envoyer commande Load Mode Register
                if timer = 0 then
                    -- Démarrer le timer pour tMRD
                    next_state <= st_idle;
                end if;

            ----------------------------------------------------------------
            -- État Idle
            ----------------------------------------------------------------
            when st_idle =>
                -- Vérifier si on doit rafraîchir ou si une demande user arrive
                if refresh_cnt = 0 then
                    -- Besoin d'un refresh
                    next_state <= st_refresh;
                elsif user_we = '1' then
                    next_state <= st_activate;
                elsif user_re = '1' then
                    next_state <= st_activate;
                else
                    next_state <= st_idle;
                end if;

            ----------------------------------------------------------------
            -- Activer la row
            ----------------------------------------------------------------
            when st_activate =>
                -- Envoyer commande Activate (RAS=0, CAS=1, WE=1)
                -- Sélection de la bank + row
                -- Puis attendre tRCD avant Read/Write
                if timer = 0 then
                    if user_we = '1' then
                        next_state <= st_write;
                    else
                        next_state <= st_read;
                    end if;
                end if;

            ----------------------------------------------------------------
            -- Lecture
            ----------------------------------------------------------------
            when st_read =>
                -- Envoyer commande Read (RAS=1, CAS=0, WE=1)
                -- Attendre tCAS avant que les données soient valides
                -- On lit DRAM_DQ sur quelques cycles
                if timer = 0 then
                    next_state <= st_precharge;  -- ou st_idle si burst plus long
                end if;

            ----------------------------------------------------------------
            -- Écriture
            ----------------------------------------------------------------
            when st_write =>
                -- Envoyer commande Write (RAS=1, CAS=0, WE=0)
                -- Présenter user_data_in sur DRAM_DQ
                if timer = 0 then
                    next_state <= st_precharge;
                end if;

            ----------------------------------------------------------------
            -- Precharge
            ----------------------------------------------------------------
            when st_precharge =>
                -- Envoyer commande Precharge (All ou bank) 
                if timer = 0 then
                    next_state <= st_idle;
                end if;

            ----------------------------------------------------------------
            -- Refresh
            ----------------------------------------------------------------
            when st_refresh =>
                -- Envoyer commande Auto-Refresh
                if timer = 0 then
                    next_state <= st_idle;
                end if;

            when others =>
                next_state <= st_reset;
        end case;
    end process;

    ----------------------------------------------------------------
    -- Logique de sortie : signaux DRAM_xxx, user_ack, etc.
    ----------------------------------------------------------------
    process(current_state)
    begin
        -- Valeurs par défaut (inactives)
        DRAM_CKE   <= '1';  -- Activer l’horloge SDRAM
        DRAM_CS_N  <= '0';  -- Sélection active
        DRAM_RAS_N <= '1';
        DRAM_CAS_N <= '1';
        DRAM_WE_N  <= '1';
        DRAM_BA    <= (others => '0');
        DRAM_ADDR  <= (others => '0');
        DRAM_LDQM  <= '0';
        DRAM_UDQM  <= '0';
        dq_out     <= (others => '0');
        dq_oe      <= '0';
        user_ack   <= '0';

        case current_state is

            when st_init_precharge_all =>
                -- Commande Precharge All : RAS=0, CAS=1, WE=0, A10=1
                DRAM_RAS_N <= '0';
                DRAM_CAS_N <= '1';
                DRAM_WE_N  <= '0';
                DRAM_ADDR(10) <= '1';  -- bit A10 = 1 => Precharge All

            when st_init_refresh_1 | st_init_refresh_2 | st_refresh =>
                -- Commande Auto-Refresh : RAS=0, CAS=0, WE=1
                DRAM_RAS_N <= '0';
                DRAM_CAS_N <= '0';
                DRAM_WE_N  <= '1';

            when st_init_load_mode =>
                -- Commande Load Mode Register
                -- Exemple : CAS Latency = 2, burst length = 1, etc.
                DRAM_RAS_N <= '0';
                DRAM_CAS_N <= '0';
                DRAM_WE_N  <= '0';
                -- DRAM_ADDR <= configuration du mode register
                -- par ex. A[6:4] = CAS latency, A[3] = mode, etc.

            when st_activate =>
                -- RAS=0, CAS=1, WE=1 => Activate
                DRAM_RAS_N <= '0';
                DRAM_BA <= user_addr(23 downto 22);   -- Sélection de la bank
                DRAM_ADDR <= user_addr(21 downto 9); -- Row address (13 bits)

            when st_read =>
                -- RAS=1, CAS=0, WE=1 => Read
                DRAM_RAS_N <= '1';
                DRAM_CAS_N <= '0';
                DRAM_WE_N  <= '1';
                DRAM_BA <= user_addr(23 downto 22);
                DRAM_ADDR <= user_addr(8 downto 0);  -- Column address (9 bits?)
                -- CAS latency -> on récupère DRAM_DQ après tCAS cycles
                -- user_data_out <= DRAM_DQ (dans un process synchrone décalé de tCAS)

            when st_write =>
                -- RAS=1, CAS=0, WE=0 => Write
                DRAM_RAS_N <= '1';
                DRAM_CAS_N <= '0';
                DRAM_WE_N  <= '0';
                DRAM_BA <= user_addr(23 downto 22);
                DRAM_ADDR <= user_addr(8 downto 0);
                dq_out     <= user_data_in;
                dq_oe      <= '1';

            when st_precharge =>
                -- Precharge
                DRAM_RAS_N <= '0';
                DRAM_WE_N  <= '0';
                -- A10=1 => Precharge all ?

            when st_idle =>
                -- Fin d’opération => user_ack = '1' si on a fini la lecture/écriture
                user_ack <= '1';

            when others =>
                null;
        end case;
    end process;

end architecture RTL;
