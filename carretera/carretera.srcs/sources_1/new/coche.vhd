library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TrafficControl is
    Port (
        clk          : in STD_LOGIC;       -- Reloj principal
        reset        : in STD_LOGIC;       -- Botón de reinicio
        car_pos      : in STD_LOGIC_VECTOR(3 downto 0); -- Posición del coche (4 LEDs)
        road_pattern : out STD_LOGIC_VECTOR(7 downto 0); -- Displays de carretera
        leds         : out STD_LOGIC_VECTOR(3 downto 0)  -- LEDs de posición del coche
    );
end TrafficControl;

architecture Behavioral of TrafficControl is
    signal road : STD_LOGIC_VECTOR(7 downto 0) := "11000000"; -- Patrón inicial de carretera
    signal cnt  : integer range 0 to 50000000 := 0;          -- Contador para el reloj lento
    signal dir  : STD_LOGIC := '1';                          -- Dirección de movimiento
begin

    -- Proceso para generar movimiento aleatorio de la carretera
    process(clk, reset)
    begin
        if reset = '1' then
            road <= "11000000";
            cnt <= 0;
            dir <= '1';
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
                cnt <= 0;
            else
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    -- Salida de los LEDs
    leds <= car_pos;

    -- Salida de los displays
    road_pattern <= road;

end Behavioral;
