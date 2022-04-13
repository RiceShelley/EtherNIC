library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MAC_pack.all;
use work.eth_pack.all;

entity frame_builder_pipe is
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        frame_ready_out     : out std_logic;
        -- AXI Data Stream Slave
        s_axis_tdata        : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tvalid       : in std_logic;
        s_axis_tready       : out std_logic;
        s_axis_tlast        : in std_logic;
        -- AXI Data Stream Master
        m_axis_tdata        : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic
    );
end entity frame_builder_pipe;

architecture rtl of frame_builder_pipe is
    signal crc_axis_tdata   : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal crc_axis_tstrb   : std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
    signal crc_axis_tvalid  : std_logic;
    signal crc_axis_tready  : std_logic;
    signal crc_axis_tlast   : std_logic;

    signal preamble_sfd_pipe        : std_logic_vector(START_SEQ_WIDTH - 1 downto 0) := (others => '0');
    signal preamble_sfd_en_pipe     : std_logic_vector(START_SEQ_SIZE - 1 downto 0) := (others => '0');
    signal crc_done_delay           : std_logic_vector(START_SEQ_SIZE - 1 downto 0) := (others => '0');

    signal data_in_en_buff : std_logic;
    signal new_frame : std_logic;

    signal fifo_input_data  : std_logic_vector(7 downto 0);
    signal fifo_in_en       : std_logic;

    signal frame_fifo_full  : std_logic;

    signal empty : std_logic;
    signal crc_done : std_logic;

    signal skid_m_axis_tdata    : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal skid_m_axis_tvalid   : std_logic;
    signal skid_m_axis_tready   : std_logic;

    signal test : std_logic;
    signal wait_for_frame_end : std_logic := '0';
begin

    -----------------------------
    -- CRC gen
    -----------------------------
    tx_crc_pipe_inst : entity work.tx_crc_pipe(rtl)
    port map (
        clk             => clk,
        crc_done_out    => crc_done,
        -- AXI Data Stream Slave
        s_axis_tdata    => s_axis_tdata,
        s_axis_tvalid   => s_axis_tvalid,
        s_axis_tlast    => s_axis_tlast,
        -- AXI Data Stream Master
        m_axis_tdata    => crc_axis_tdata,
        m_axis_tvalid   => crc_axis_tvalid, 
        m_axis_tready   => crc_axis_tready
    );
    
    -----------------------------
    -- Detect new frame
    -----------------------------
    new_frame <= '1' when (data_in_en_buff = '0' and s_axis_tvalid = '1' and wait_for_frame_end = '0') else '0';
    detect_frame_proc : process(clk) begin
        if rising_edge(clk) then
            data_in_en_buff <= s_axis_tvalid;
            if (new_frame = '1') then
                wait_for_frame_end <= '1';
            elsif (crc_done = '1') then
                wait_for_frame_end <= '0';
            end if;
        end if;
    end process detect_frame_proc;

    -----------------------------
    -- Append preamble and SFD
    -----------------------------
    preamble_sfd_proc : process(clk) begin
        if rising_edge(clk) then
            if (new_frame = '1') then
                preamble_sfd_pipe       <= START_SEQ;
                preamble_sfd_en_pipe    <= (others => '1');
                crc_done_delay          <= (others => '0');
            else
                preamble_sfd_pipe       <= preamble_sfd_pipe((START_SEQ_WIDTH - 9) downto 0) & crc_axis_tdata;
                preamble_sfd_en_pipe    <= preamble_sfd_en_pipe((START_SEQ_SIZE - 2) downto 0) & crc_axis_tvalid;
                crc_done_delay          <= crc_done_delay((START_SEQ_SIZE - 2) downto 0) & crc_done;
            end if;
        end if;
    end process preamble_sfd_proc;

    fifo_input_data <= preamble_sfd_pipe(START_SEQ_WIDTH - 1 downto START_SEQ_WIDTH - 8);
    fifo_in_en      <= preamble_sfd_en_pipe(START_SEQ_SIZE - 1);
    frame_ready_out <= crc_done_delay(START_SEQ_SIZE - 1);

    -----------------------------
    -- Frame fifo
    -----------------------------
    skid_m_axis_tvalid   <= not empty;
    s_axis_tready   <= not frame_fifo_full;

    frame_fifo : entity work.sync_fifo(rtl)
    generic map (
        DEPTH   => MAX_ETH_FRAME_SIZE
    ) port map (
        clk         => clk,
        rst         => rst,
        -- Write port
        wr_data     => fifo_input_data,
        wr_en       => fifo_in_en,
        full        => frame_fifo_full,
        -- Read port
        rd_data     => skid_m_axis_tdata,
        rd_en       => skid_m_axis_tready,
        empty       => empty
    );

    fifo_out_skid : entity work.skid_buffer(rtl)
    generic map (
        DATA_WIDTH      => m_axis_tdata'length
    ) port map (
        clk             => clk,
        clr             => rst,
        input_valid     => skid_m_axis_tvalid,
        input_ready     => skid_m_axis_tready,
        input_data      => skid_m_axis_tdata,
        output_valid    => m_axis_tvalid,
        output_ready    => m_axis_tready,
        output_data     => m_axis_tdata
    );
end architecture rtl;