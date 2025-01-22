library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TrafficControl_tb is
end TrafficControl_tb;

architecture Behavioral of TrafficControl_tb is
    -- Señales para simular las entradas
    signal clk         : STD_LOGIC := '0';
    signal reset       : STD_LOGIC := '0';
    signal car_pos     : STD_LOGIC_VECTOR(3 downto 0) := "0000";

    -- Señales para capturar las salidas
    signal road_pattern : STD_LOGIC_VECTOR(7 downto 0);
    signal leds         : STD_LOGIC_VECTOR(3 downto 0);
    signal spi_mosi     : STD_LOGIC;
    signal spi_miso     : STD_LOGIC := '0';
    signal spi_clk      : STD_LOGIC := '0';
    signal spi_cs       : STD_LOGIC;

begin
    -- Instancia de la unidad bajo prueba (UUT)
    uut: entity work.TrafficControl
        port map (
            clk          => clk,
            reset        => reset,
            car_pos      => car_pos,
            road_pattern => road_pattern,
            leds         => leds,
            spi_mosi     => spi_mosi,
            spi_miso     => spi_miso,
            spi_clk      => spi_clk,
            spi_cs       => spi_cs
        );

    -- Generación del reloj
    clk_process : process
    begin
        clk <= '0';
        wait for 5 ns; -- Período de 10 ns (100 MHz)
        clk <= '1';
        wait for 5 ns;
    end process;

    -- Generación de estímulos
    stim_process : process
    begin
        -- Reset activo
        reset <= '1';
        wait for 20 ns;
        reset <= '0';

        -- Simular posiciones del coche
        car_pos <= "0001"; -- LED[0] encendido
        wait for 100 ns;
        car_pos <= "0010"; -- LED[1] encendido
        wait for 100 ns;
        car_pos <= "0100"; -- LED[2] encendido
        wait for 100 ns;
        car_pos <= "1000"; -- LED[3] encendido

        -- Finalizar simulación
        wait;
    end process;
end Behavioral;


end Behavioral;
