-- Serial-in Serial-out MDIO

library ieee;

entity mdio is
	generic (
		REGISTER_SIZE : natural := 16;
		NUM_REGISTERS : natural := 32;
	);
	port (
		clk : in std_logic;
		serial_in : in std_logic;
		data : out std_logic_vector(REGISTER_SIZE downto 0) := (others => '0');
	);
end entity mdio;

architecture clause22 of mdio is
	signal reg_array : std_logic_vector(NUM_REGISTERS-1 downto 0)(REGISTER_SIZE-1 downto 0) := (others => "00000000");
	constant PREAMBLE_LENGTH : natural := 32;
	
	signal opcode : std_logic_vector;
	constant COUNTER_SIZE : natural := REGISTER_SIZE;
	constant ADDRESS_SIZE : natural := 5
	signal counter : std_logic_vector(COUNTER_SIZE downto 0) := (others => '0');
	signal counter_running : std_logic := '0';
	signal next_count : std_logic := '0';
	
	signal preamble_state : std_logic := '0';
	signal next_preamble_state : std_logic := '0';
	signal command_state : std_logic := '0';
	signal start_state : std_logic := '0';
	type MdioState is (ZZZ, PREAMBLE, ST0, ST1, OP0, OP1, RD, WR, PA, RA, TA0, TA1, DATA, ACT);
    signal current_state : MdioState := ZZZ;
	signal next_state : MdioState := ZZZ;
begin

	count_and_state_assigner : process(clk) begin
		if rising_edge(clk) then
			counter <= next_count_state;
			state <= next_state;
		end if;
	end process;

	next_preamble_proc : process(serial_in) begin	-- Not needed anymore?
		if serial_in = '1' then
			next_preamble_state = '1';
		else
			next_preamble_state = '0';
		end if;
	end process;

	next_count_proc : process (current_state, counter, serial_in) begin
		case current_state is
			when ZZZ =>
--------------- ZZZ Next count logic
				next_count <= to_integer(unsigned('0'));
--------------- ZZZ Next state logic
				if serial_in = '1' then
					next_state <= PREAMBLE;
				else
					next_state <= ZZZ;	-- Sleep/listen state
				end if;
			when PREAMBLE =>
--------------- PREAMBLE Next count logic
				if to_integer(unsigned(counter)) < PREAMBLE_LENGTH then
					next_count <= std_logic_vector(to_unsigned(to_integer(unsigned( counter )) + 1, COUNTER_SIZE));
				else
					next_count <= (others => '0');
--------------- PREAMBLE Next state logic
				if serial_in = '1' then
					if to_integer(unsigned(counter)) >= PREAMBLE_LENGTH then
						next_state <= ZZZ;		-- Back to sleep if preamble too long
					elsif to_integer(unsigned(counter)) < PREAMBLE_LENGTH;
						next_state <= PREAMBLE;	-- Stay in PREAMBLE while receiving PREAMBLE ones
					else
						next_state <= ZZZ;		-- If invalid state, return to sleep
					end if;
				elsif serial_in = '0' then		-- After 32 ones, next bit must be 0 to reach ST state
					if to_integer(unsigned(counter)) = PREAMBLE_LENGTH then
						next_state <= ST0;		-- START state after 32 bits of preamble
					else
						next_state <= ZZZ;		-- Back to  state if not 32 ones
					end if;
				else
					next_state <= ZZZ;			-- Go back to sleep if invalid input
				end if;
			when ST0 =>
--------------- ST0 Next state logic
--------------- Does not use counter
--------------- ST0 means that 0 was received after 32 ones in PREAMBLE
				if serial_in = '1' then		-- Input 1 = 01 received for START
					next_count <= (others => '0');
					next_state <= ST1;
				elsif serial_in = '0' then	-- Input 0 = 00. Invalid value for START
					next_count <= (others => '0');
					next_state <= ZZZ;		-- Go back to sleep.
				else then					-- Go back to sleep if invalid input.
					next_count <= (others => '0');
					next_state <= ZZZ;
				end if;
			when ST1 =>
--------------- ST1 Next state logic
--------------- Does not use counter
--------------- ST1 means 01 was received as START
				if serial_in = '0' then
					next_count <= (others => '0');
					next_state <= OP0;		-- First bit of opcode is 0
				elsif serial_in = '1' then
					next_count <= (others => '0');
					next_state <= OP1;		-- First bit of opcode is 1
				else then					-- Go back to sleep if invalid input.
					next_count <= (others => '0');
					next_state <= ZZZ;
				end if;
			when OP0 =>
--------------- OP0 Next state logic
--------------- Does not use counter
--------------- OP0 means 0 was received as first bit of OPCODE
				if serial_in = '1' then
					next_count <= (others => '0');
					next_state <= WR;		-- Opcode 01 = WRITE.
				else
					next_count <= (others => '0');
					next_state <= ZZZ;		-- No other options are valid.
			when OP1 =>
--------------- OP1 Next state logic
--------------- Does not use counter
--------------- OP1 means 1 was received as first bit of OPCODE
				if serial_in = '0' then
					next_count <= (others => '0');
					next_state <= RD;		-- Opcode 10 = READ.
				else
					next_count <= (others => '0');
					next_state <= ZZZ;		-- No other options are valid.
			when WR/RD =>
--------------- WR/RD Next state logic
--------------- Does not use counter
--------------- WR means the WRITE command was requested.
--------------- RD means the READ command was requested.
--------------- 
--------------- Next state logic
				next_count <= std_logic_vector(to_unsigned(to_integer(1, COUNTER_SIZE));
				--next_count <= (others => '0');
				next_state <= PA;
			when PA =>
--------------- PHY Address Next state/count logic
				if to_integer(unsigned(counter)) = ADDRESS_SIZE then
					next_count <= (others => '0');
					next_state <= RA;
				elsif to_integer(unsigned(counter)) < ADDRESS_SIZE then
					next_count <= std_logic_vector(to_unsigned(to_integer(unsigned( counter )) + 1, COUNTER_SIZE));
					next_state <= PA;
				else
					next_count <= (others => '0');
					next_state <= ZZZ;
				end if;
			when RA =>
--------------- Register Address (Clause 22)
				if to_integer(unsigned(counter)) = ADDRESS_SIZE then
					next_count <= (others => '0');
					next_state <= TA0;
				elsif to_integer(unsigned(counter)) < ADDRESS_SIZE then
					next_count <= std_logic_vector(to_unsigned(to_integer(unsigned( counter )) + 1, COUNTER_SIZE));
					next_state <= RA;
				else
					next_count <= (others => '0');
					next_state <= ZZZ;
				end if;
			when TA0 =>
--------------- 1st clock cycle to skip before DATA
				next_count <= (others => '0');
				next_state <= TA1;
			when TA1 =>
--------------- 2nd clock cycle to skip before DATA
				next_count <= (others => '0');
				next_state <= DATA;
			when DATA =>
--------------- Take in/send out data in the register.
				if to_integer(unsigned(counter)) = REGISTER_SIZE then
					next_count <= (others => '0');
					next_state <= ACT;
				elsif to_integer(unsigned(counter)) < REGISTER_SIZE then
					next_count <= std_logic_vector(to_unsigned(to_integer(unsigned( counter )) + 1, COUNTER_SIZE));
					next_state <= DATA;
				else
					next_count <= (others => '0');
					next_state <= ZZZ;
				end if;
			when ACT =>
--------------- Extra state for moving data into registers.
				next_count <= (others => '0');
				next_state <= ZZZ;
			when others =>
				report "Illegal next count state encountered" severity warning;
				next_count <= "00";
		end case;
    end process;
end architecture clause22;

--case counter is
--					when "00" => next_count <= "01";
--					when "01" => next_count <= "10";
--					when "10" => next_count <= "11";
--					when "11" => next_count <= "00";
--					when others => next_count <= "00";
--				end case;