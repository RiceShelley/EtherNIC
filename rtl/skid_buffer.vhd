library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity skid_buffer is
    generic (
        DATA_WIDTH : natural := 8;
        ASYNC_INPUT : string := "FALSE"
    );
    port (
        clk : in std_logic;
        clr : in std_logic;

        input_valid     : in std_logic;
        input_ready     : out std_logic;
        input_data      : in std_logic_vector(DATA_WIDTH - 1 downto 0); 

        output_valid    : out std_logic;
        output_ready    : in std_logic;
        output_data     : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity skid_buffer;

architecture rtl of skid_buffer is

    signal input_ready_r : std_logic;
    signal output_valid_r : std_logic;

    signal data_buffer_wren : std_logic := '0';

    signal data_buffer_out : std_logic_vector(DATA_WIDTH - 1 downto 0);
    
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of data_buffer_out : signal is ASYNC_INPUT;

    signal data_out_wren : std_logic := '0';
    signal use_buffered_data : std_logic := '0';
    signal selected_data : std_logic_vector(DATA_WIDTH - 1 downto 0);

    type skid_state_t is (EMPTY, BUSY, FULL);
    signal state : skid_state_t := EMPTY;
    signal state_next : skid_state_t := EMPTY;

    signal insert : std_logic := '0';
    signal remove : std_logic := '0';

    signal load     : std_logic := '0';
    signal flow     : std_logic := '0';
    signal fill     : std_logic := '0';
    signal flush    : std_logic := '0';
    signal unload   : std_logic := '0';

    function get_next_state(load : std_logic;
                            flow : std_logic;
                            fill : std_logic;
                            flush : std_logic;
                            unload : std_logic;
                            state : skid_state_t)
    return skid_state_t is
        variable next_state : skid_state_t;
    begin
        if load = '1' then 
            next_state := BUSY;
        else 
            next_state := state;
        end if;

        if flow = '1' then
            next_state := BUSY;
        end if;

        if fill = '1' then
            next_state := FULL;
        end if;

        if flush = '1' then
            next_state := BUSY;
        end if;

        if unload = '1' then
            next_state := EMPTY;
        end if;

        return next_state;
    end function get_next_state;
begin

    input_ready <= input_ready_r;
    output_valid <= output_valid_r;

    reg1_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then
                data_buffer_out <= (others => '0');
            else
                if data_buffer_wren = '1' then
                    data_buffer_out <= input_data;
                end if;
            end if;
        end if;
    end process reg1_proc;

    selected_data <= data_buffer_out when (use_buffered_data = '1') else input_data;

    reg2_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then
                output_data <= (others => '0');
            else
                if data_out_wren = '1' then
                    output_data <= selected_data;
                end if;
            end if;
        end if;
    end process reg2_proc;

    -- Control logic
    comp_ready_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then
                input_ready_r <= '1';
            else
                if state_next /= FULL then
                    input_ready_r <= '1';
                else
                    input_ready_r <= '0';
                end if;
            end if;
        end if;
    end process comp_ready_proc;

    comp_valid_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then
                output_valid_r <= '0';
            else
                if state_next /= EMPTY then
                    output_valid_r <= '1';
                else
                    output_valid_r <= '0';
                end if;
            end if;
        end if;
    end process comp_valid_proc;

    insert <= input_valid and input_ready_r;
    remove <= output_valid_r and output_ready;

    load <= '1' when (state = EMPTY and insert = '1' and remove = '0') else '0';
    flow <= '1' when (state = BUSY and insert = '1' and remove = '1') else '0';
    fill <= '1' when (state = BUSY and insert = '1' and remove = '0') else '0';
    flush <= '1' when (state = FULL and insert = '0' and remove = '1') else '0';
    unload <= '1' when (state = BUSY and insert = '0' and remove = '1') else '0';

    state_next <= get_next_state(load, flow, fill, flush, unload, state);

    update_state_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then
                state <= EMPTY;
            else
                state <= state_next;
            end if;
        end if;
    end process update_state_proc;

    data_out_wren <= load or flow or flush;
    data_buffer_wren <= fill;
    use_buffered_data <= flush;

end architecture rtl;