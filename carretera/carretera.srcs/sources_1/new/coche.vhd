library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TrafficControl is
    Port (
        clk          : in STD_LOGIC;       -- Reloj principal
        reset        : in STD_LOGIC;       -- Botón de reinicio
        car_pos      : in STD_LOGIC_VECTOR(3 downto 0); -- Posición del coche (4 LEDs)
        road_pattern : out STD_LOGIC_VECTOR(7 downto 0); -- Displays de carretera
        leds         : out STD_LOGIC_VECTOR(3 downto 0);  -- LEDs de posición del coche
        spi_mosi     : out STD_LOGIC;
        spi_clk      : buffer STD_LOGIC;
        spi_cs       : out STD_LOGIC
    );
end TrafficControl;

architecture Behavioral of TrafficControl is
    signal road      : STD_LOGIC_VECTOR(7 downto 0) := "11000000"; -- Patrón inicial de carretera
    signal cnt       : integer range 0 to 50000000 := 0;           -- Contador para el reloj lento
    signal dir       : STD_LOGIC := '1';                           -- Dirección de movimiento
    signal score     : integer range 0 to 9999 := 0;
    signal spi_bit   : integer range 0 to 15 := 0;
    signal spi_data  : STD_LOGIC_VECTOR(15 downto 0);
    signal spi_ready : STD_LOGIC := '1';
begin

    -- Proceso para generar movimiento de la carretera
    process(clk, reset)
    begin
        if reset = '1' then
            road <= "11000000";
            cnt <= 0;
            dir <= '1';
            score <= 0;
        elsif rising_edge(clk) then
            if cnt = 50000000 then
                -- Movimiento de la carretera
                if dir = '1' then
                    road <= road(6 downto 0) & '0';
                else
                    road <= '0' & road(7 downto 1);
                end if;

                -- Cambio de dirección aleatorio
                dir <= NOT dir;

                -- Incrementar puntuación
                score <= score + 1;
                if score > 9999 then
                    score <= 9999;
                end if;

                cnt <= 0;
            else
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    -- Proceso para transmitir la puntuación a través de SPI
    process(clk, reset)
    begin
        if reset = '1' then
            spi_mosi <= '0';
            spi_clk <= '0';
            spi_cs <= '1';
            spi_bit <= 0;
            spi_ready <= '1';
        elsif rising_edge(clk) then
            if spi_ready = '1' then
                spi_cs <= '0';
                spi_data <= std_logic_vector(to_unsigned(score, 16));
                spi_bit <= 15;
                spi_ready <= '0';
            elsif spi_bit >= 0 then
                spi_mosi <= spi_data(spi_bit);
                spi_clk <= NOT spi_clk;
                if spi_clk = '1' then
                    spi_bit <= spi_bit - 1;
                end if;
            else
                spi_cs <= '1';
                spi_ready <= '1';
            end if;
        end if;
    end process;

    -- Salida de los LEDs
    leds <= car_pos;

    -- Salida de los displays
    road_pattern <= road;

end Behavioral;