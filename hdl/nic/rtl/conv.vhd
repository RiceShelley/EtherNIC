library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv is
    generic (
        PIX_IN_WIDTH    : natural := 8;
        PIX_OUT_WIDTH   : natural := 8 * 2;
        KERN_SIZE       : natural := 3;
        FRAME_WIDTH     : natural := 640
    );
    port (
        clk             : in std_logic;
        rst             : in std_logic;
        pass            : in std_logic;
        new_row         : in std_logic;
        send_pkt_out    : out std_logic;
        -- AXI stream slave
        s_axis_tvalid   : in std_logic;
        s_axis_tdata    : in std_logic_vector(PIX_IN_WIDTH - 1 downto 0);
        s_axis_tready   : out std_logic;
        -- AXI stream master
        m_axis_tvalid   : out std_logic;
        m_axis_tdata    : out std_logic_vector(7 downto 0);
        m_axis_tready   : in std_logic
    );
end entity conv;

architecture rtl of conv is

    signal mat_axis_tvalid  : std_logic;
    signal mat_axis_tdata   : std_logic_vector(PIX_IN_WIDTH * KERN_SIZE - 1 downto 0);
    signal mat_axis_tready  : std_logic;

    type mat_t is array(0 to KERN_SIZE - 1) of std_logic_vector(PIX_IN_WIDTH * KERN_SIZE - 1 downto 0);
    signal vidMat : mat_t;
    signal vecMat : std_logic_vector(PIX_IN_WIDTH * KERN_SIZE ** 2 - 1 downto 0);
    signal startConv : std_logic;
    signal vidMatVec : std_logic_vector(PIX_IN_WIDTH * KERN_SIZE ** 2 - 1 downto 0);
    signal pixOut : std_logic_vector(PIX_OUT_WIDTH - 1 downto 0);
    signal convDone : std_logic;

    signal cols_cnt : natural := 0;

    signal dout_next_byte   : std_logic_vector(7 downto 0);
    signal dout_nbyte_valid : std_logic := '0'; 

    signal dout_fifo_full : std_logic;

    signal oFifoData    : std_logic_vector(15 downto 0);
    signal oFifoPixRd   : std_logic;
    signal oFifoEmpty   : std_logic;

begin

    -- Video memory for spatial filter
    vid_mem_inst : entity work.vid_mem(rtl)
    port map (
        clk             => clk,
        clr             => rst,
        -- Camera data in
        s_axis_tvalid   => s_axis_tvalid,
        s_axis_tdata    => s_axis_tdata,
        s_axis_tready   => s_axis_tready,
        -- Conv data out
        m_axis_tvalid   => mat_axis_tvalid,
        m_axis_tdata    => mat_axis_tdata,
        m_axis_tready   => mat_axis_tready
    );

    -- Feed conv pipes from Video memory
    feed_conv_pipe_proc : process(clk) begin
        if rising_edge(clk) then
            mat_axis_tready <= '1';
            startConv       <= '0';
            send_pkt_out    <= '0';
            if mat_axis_tready = '1' and mat_axis_tvalid = '1' then
                for i in 0 to KERN_SIZE - 1 loop
                    vidMat(i) <= vidMat(i)((PIX_IN_WIDTH * 2) - 1 downto 0) 
                                    & mat_axis_tdata((i + 1) * PIX_IN_WIDTH - 1 downto i * PIX_IN_WIDTH);
                end loop;
                if cols_cnt = 0 then
                    send_pkt_out <= '1';
                end if;
                if cols_cnt > KERN_SIZE - 2 then
                    startConv <= '1';
                end if;
                if cols_cnt = (FRAME_WIDTH - 1) then
                    cols_cnt <= 0;
                else
                    cols_cnt <= cols_cnt + 1;
                end if;
            end if;
        end if;
    end process feed_conv_pipe_proc;

    vecMat <= vidMat(0) & vidMat(1) & vidMat(2);
    -- Array of conv pipes
    unfold_conv_inst : entity work.unfold_conv(rtl)
    port map (
        clk         => clk,
        rst         => rst,
        pass        => pass,
        start       => startConv,
        matIn       => vecMat,
        pixOut      => pixOut,
        done        => convDone
    );

    data_out_fifo_inst : entity work.sync_fifo(rtl)
    generic map (
        DATA_WIDTH      => pixOut'length,
        DEPTH           => FRAME_WIDTH
    ) port map (
        clk             => clk,
        rst             => rst,
        wr_data         => pixOut,
        wr_en           => convDone,
        full            => dout_fifo_full,

        rd_data         => oFifoData,
        rd_en           => oFifoPixRd,
        empty           => oFifoEmpty
    );

    -- write data out
    write_data_proc : process(clk) begin
        if rising_edge(clk) then
            m_axis_tvalid       <= '0';
            oFifoPixRd          <= '0';
            if dout_nbyte_valid = '1' then
                m_axis_tvalid       <= '1';
                m_axis_tdata        <= dout_next_byte;
                dout_nbyte_valid    <= '0';
            elsif oFifoEmpty = '0' and m_axis_tready = '1' then
                oFifoPixRd          <= '1';
                m_axis_tvalid       <= '1';
                m_axis_tdata        <= oFifoData(15 downto 8);
                dout_next_byte      <= oFifoData(7 downto 0);
                dout_nbyte_valid    <= '1';
            end if;
        end if;
    end process write_data_proc;

end architecture rtl;