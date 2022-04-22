library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Ov7670_reader is
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        new_frame           : out std_logic;
        new_row             : out std_logic;
        -- Cam signals
        pix_valid           : in std_logic;
        href                : in std_logic;
        vsync               : in std_logic;
        data_in             : in std_logic_vector(7 downto 0);
        -- AXI Data Stream Master
        m_axis_tdata        : out std_logic_vector(7 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic
    );
end entity Ov7670_reader;

architecture rtl of Ov7670_reader is

    signal cam_data_r : std_logic_vector(7 downto 0);

    signal pix_valid_buff   : std_logic_vector(2 downto 0);
    signal href_buff        : std_logic_vector(2 downto 0);
    signal vsync_buff       : std_logic_vector(2 downto 0);

    signal pix_valid_r      : std_logic;
    signal href_r           : std_logic;
    signal vsync_r          : std_logic;

    signal pix_valid_re     : std_logic;
    signal href_re          : std_logic;
    signal vsync_re         : std_logic;

    signal wr_ofifo_data    : std_logic_vector(7 downto 0);
    signal wr_ofifo_en      : std_logic := '0';
    signal wr_ofifo_full    : std_logic := '0';
    signal ofifo_empty      : std_logic := '0';

    signal active_byte      : std_logic := '1';

begin

    new_frame <= vsync_re;
    new_row   <= href_re;

    sync_data_in_inst : entity work.simple_pipe(rtl)
    generic map (
        PIPE_WIDTH  => data_in'length,
        DEPTH       => 2
    ) port map (
        clk         => clk,
        pipe_in     => data_in,
        pipe_out    => cam_data_r
    );

    buff_proc : process(clk) begin
        if rising_edge(clk) then
            if rst /= '0' then
                pix_valid_buff  <= (others => '0');
                href_buff       <= (others => '0');
                vsync_buff      <= (others => '0');
            else
                pix_valid_buff      <= pix_valid_buff(pix_valid_buff'left - 1 downto 0) & pix_valid;
                href_buff           <= href_buff(href_buff'left - 1 downto 0) & href;
                vsync_buff          <= vsync_buff(vsync_buff'left - 1 downto 0) & vsync;
            end if;
        end if;
    end process buff_proc;

    pix_valid_r <= pix_valid_buff(pix_valid_buff'left);
    href_r      <= href_buff(href_buff'left);
    vsync_r     <= vsync_buff(vsync_buff'left);
    
    pix_valid_re    <= '1' when (pix_valid_buff(pix_valid_buff'left) = '0' and pix_valid_buff(pix_valid_buff'left - 1) = '1') else '0';
    href_re         <= '1' when (href_buff(href_buff'left) = '0' and href_buff(href_buff'left - 1) = '1') else '0';
    vsync_re        <= '1' when (vsync_buff(vsync_buff'left) = '0' and vsync_buff(vsync_buff'left - 1) = '1') else '0';

    -- Capture data
    cap_data_proc : process(clk) begin
        if rising_edge(clk) then
            wr_ofifo_en <= '0';
            if href_re = '1' then
                active_byte <= '1';
            elsif pix_valid_re = '1' and href_r = '1' then
                if active_byte = '1' then
                    wr_ofifo_data   <= cam_data_r;
                    wr_ofifo_en     <= '1';
                    active_byte     <= '0';
                else 
                    active_byte     <= '1';
                end if;
            end if;
        end if;
    end process cap_data_proc;

    m_axis_tvalid <= not ofifo_empty;
    data_out_fifo_inst : entity work.sync_fifo(rtl)
    generic map (
        DATA_WIDTH  => 8,
        DEPTH       => 8
    ) port map (
        clk     => clk,
        rst     => rst,
        wr_data => wr_ofifo_data,
        wr_en   => wr_ofifo_en,
        full    => wr_ofifo_full,
        rd_data => m_axis_tdata,
        rd_en   => m_axis_tready,
        empty   => ofifo_empty
    );

end architecture rtl;