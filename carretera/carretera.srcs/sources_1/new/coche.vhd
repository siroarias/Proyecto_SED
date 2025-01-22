library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TrafficControl is
    Port (
        clk          : in STD_LOGIC;       -- Reloj principal
        reset        : in STD_LOGIC;       -- Botón de reinicio
        car_pos      : in STD_LOGIC_VECTOR(3 downto 0); -- Posición del coche (4 LEDs)
        road_pattern : buffer STD_LOGIC_VECTOR(7 downto 0); -- Displays de carretera
        leds         : out STD_LOGIC_VECTOR(9 downto 0);  -- LEDs de posición del coche
        spi_mosi     : out STD_LOGIC;
        spi_miso     : in  STD_LOGIC;
        spi_clk      : out STD_LOGIC;
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
    signal command   : STD_LOGIC_VECTOR(1 downto 0) := "00";       -- Comando recibido por SPI
    signal leds_internal : STD_LOGIC_VECTOR(9 downto 0) := (others => '0'); -- LEDs de 10 bits
    signal car_pos_int : integer range 0 to 9 := 0;                -- Posición interna del coche
    signal segment_pattern : STD_LOGIC_VECTOR(7 downto 0); -- Representa el patrón de 7 segmentos
    signal visible_pattern : STD_LOGIC_VECTOR(7 downto 0); -- Representa qué dígitos están visibles
    type segment_array is array (7 downto 0) of STD_LOGIC_VECTOR(6 downto 0); -- 8 dígitos, 7 segmentos cada uno
    signal full_segment_pattern : segment_array := (others => (others => '0')); -- Inicializar todos los segmentos apagados
    signal spi_clk_internal : STD_LOGIC := '0'; -- Señal interna para el reloj SPI
begin

    -- Proceso para generar movimiento de la carretera y actualizar el patrón del display
    process(clk, reset)
    begin
        if reset = '1' then
            road <= "11000000";
            cnt <= 0;
            dir <= '1';
            visible_pattern <= (others => '1'); -- Todos los dígitos visibles inicialmente
            full_segment_pattern <= (others => (others => '0')); -- Todos los segmentos apagados
            road_pattern <= (others => '0'); -- Todos los segmentos apagados
        elsif rising_edge(clk) then
            -- Movimiento de la carretera
            if cnt = 50000000 then
                if dir = '1' then
                    road <= road(6 downto 0) & '0';
                else
                    road <= '0' & road(7 downto 1);
                end if;
                cnt <= 0;
            else
                cnt <= cnt + 1;
            end if;

            -- Generar visible_pattern apagando dígitos marcados y adyacentes
            for i in 0 to 7 loop
                if road(i) = '1' then
                    visible_pattern(i) <= '0'; -- Apagar dígito marcado
                    if i > 0 then
                        visible_pattern(i - 1) <= '0'; -- Apagar adyacente izquierdo
                    end if;
                    if i < 7 then
                        visible_pattern(i + 1) <= '0'; -- Apagar adyacente derecho
                    end if;
                else
                    visible_pattern(i) <= '1'; -- Mantener visibles los demás
                end if;
            end loop;

            -- Mapear visible_pattern a segmentos activos (7 segmentos por dígito)
            for i in 0 to 7 loop
                if visible_pattern(i) = '1' then
                    full_segment_pattern(i) <= "1111110"; -- Encender segmento g (bit 6)
                else
                    full_segment_pattern(i) <= "0000000"; -- Apagar todos los segmentos
                end if;
            end loop;

            -- Extraer solo el segmento g (bit 6) para road_pattern
            for i in 0 to 7 loop
                road_pattern(i) <= full_segment_pattern(i)(6); -- Solo segmento g
            end loop;
        end if;
    end process;  
    
   
    -- Asignar la señal interna a la salida
    spi_clk <= spi_clk_internal;

    -- Proceso para recibir comandos desde SPI
    process(spi_clk_internal, reset)
        variable spi_shift : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); -- Registro de desplazamiento
        variable bit_cnt   : integer range 0 to 7 := 0;                       -- Contador de bits
    begin
        if reset = '1' then
            spi_shift := (others => '0');
            bit_cnt := 0;
            command <= "00";
        elsif rising_edge(spi_clk_internal) then
            spi_shift := spi_shift(6 downto 0) & spi_miso; -- Desplazar los bits
            if bit_cnt = 7 then
                command <= spi_shift(1 downto 0); -- Tomar los 2 bits menos significativos como comando
                bit_cnt := 0;
            else
                bit_cnt := bit_cnt + 1;
            end if;
        end if;
    end process;

    -- Proceso para mover el coche basado en el comando recibido
    process(clk, reset)
    begin
        if reset = '1' then
            car_pos_int <= 0; -- Reiniciar posición
            command <= "00";
            leds_internal <= (others => '0');
        elsif rising_edge(clk) then
            -- Actualizar la posición del coche según el comando
            case command is
                when "01" => -- Mover a la izquierda
                    if car_pos_int > 0 then
                        car_pos_int <= car_pos_int - 1;
                    end if;
                when "10" => -- Mover a la derecha
                    if car_pos_int < 9 then -- Máximo índice 9 (10 posiciones)
                        car_pos_int <= car_pos_int + 1;
                    end if;
                when others =>
                    -- No hacer nada
            end case;

            -- Actualizar los LEDs internos
            leds_internal <= (others => '0'); -- Apagar todos los LEDs
            leds_internal(to_integer(unsigned(std_logic_vector(to_unsigned(car_pos_int, 4))))) <= '1';
        end if;
    end process;

    -- Asignar los LEDs internos a la salida
    leds <= leds_internal;

    -- Proceso para eliminar la puntuación si el coche es eliminado
    process(clk, reset)
        variable collision_detected : boolean := false;
    begin
        if reset = '1' then
            score <= 0; -- Reiniciar puntuación
        elsif rising_edge(clk) then
            collision_detected := false;

            -- Verificar colisión según la posición del coche y los dígitos encendidos
            case car_pos_int is
                when 0 => -- Coche debajo del LED 0
                    if road_pattern(0) = '1' then
                        collision_detected := true;
                    end if;
                when 1 => -- Coche debajo del LED 1
                    if road_pattern(1) = '1' then
                        collision_detected := true;
                    end if;
                when 2 => -- Coche debajo del LED 2
                    if road_pattern(2) = '1' then
                        collision_detected := true;
                    end if;
                when 3 => -- Coche debajo del LED 2
                    if road_pattern(2) = '1' then
                        collision_detected := true;
                    end if;
                when 4 => -- Coche debajo del LED 3
                    if road_pattern(3) = '1' then
                        collision_detected := true;
                    end if;
                when 5 => -- Coche debajo del LED 4
                    if road_pattern(4) = '1' then
                        collision_detected := true;
                    end if;
                when 6 => -- Coche debajo del LED 5
                    if road_pattern(5) = '1' then
                        collision_detected := true;
                    end if;
                when 7 => -- Coche debajo del LED 5 o 6
                    if road_pattern(5) = '1' or road_pattern(6) = '1' then
                        collision_detected := true;
                    end if;
                when 8 => -- Coche debajo del LED 6
                    if road_pattern(6) = '1' then
                        collision_detected := true;
                    end if;
                when 9 => -- Coche debajo del LED 7
                    if road_pattern(7) = '1' then
                        collision_detected := true;
                    end if;
                when others =>
                    -- No hacer nada
            end case;

            -- Reiniciar puntuación si hay colisión
            if collision_detected = true then
                score <= 0;
            end if;
        end if;
    end process;

    -- Proceso para transmitir la puntuación a través de SPI
 -- Proceso para transmitir la puntuación a través de SPI
    process(clk, reset)
    begin
        if reset = '1' then
            spi_mosi <= '0';
            spi_clk_internal <= '0'; -- Inicializar el reloj interno
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

                -- Generar la señal de reloj SPI interna
                spi_clk_internal <= NOT spi_clk_internal;

                -- Solo decrementar el bit en el flanco ascendente del reloj SPI interno
                if spi_clk_internal = '1' then
                    spi_bit <= spi_bit - 1;
                end if;
            else
                spi_cs <= '1';
                spi_ready <= '1';
            end if;
        end if;
    end process; 


end Behavioral;