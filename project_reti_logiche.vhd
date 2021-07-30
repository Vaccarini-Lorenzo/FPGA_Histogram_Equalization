----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 05.04.2021 19:45:50
-- Design Name:
-- Module Name: project_reti_logiche - FSM
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_reti_logiche is
port (
i_clk: in std_logic;
i_rst: in std_logic;
i_start: in std_logic;
i_data: in std_logic_vector(7 downto 0);
o_address : out std_logic_vector(15 downto 0);
o_done: out std_logic;
o_en: out std_logic;
o_we: out std_logic;
o_data: out std_logic_vector (7 downto 0)
);
end project_reti_logiche;

architecture FSM of project_reti_logiche is

    type state_type is (RESET, START, DIM, CYCLE, TMP_STATE,UPDATE, END_CYCLE, LOG, SHIFT_STATE, LOAD_ADDRESS, LOAD_PIXEL,TMP_PIXEL, NEW_PIXEL, WRITE, DONE);
    signal curr_state, next_state: state_type;
    signal tmp_byte, delta, pxl: unsigned (7 downto 0);
    signal tmp_pxl: unsigned (15 downto 0);
    signal pxl_addr: unsigned (15 downto 0);
    signal shift_level, log_delta: unsigned (3 downto 0);
    signal address, tmp_address, w_address, tmp_waddress, counter, tmp_counter, dimension: unsigned(15 downto 0);
    signal min: unsigned(7 downto 0);
    signal max: unsigned(7 downto 0);
    signal new_pxl: std_logic_vector(7 downto 0);
    signal flag: std_logic;


begin
    -- Update the current state
    state_update: process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            curr_state <= RESET;
        elsif rising_edge(i_clk) then
            curr_state <= next_state;
        end if;
    end process;

    -- Update the next state
    transition_function: process(i_clk)
    begin
    if rising_edge(i_clk) then
        next_state <= RESET;
        
        case curr_state is
        when RESET =>
            if (i_start = '1') then
                next_state <= START;
            else
                next_state <= RESET;
            end if;

        when START =>
            if (unsigned(i_data) /= "00000000") then
                next_state <= DIM;
            else
                next_state <= DONE;
            end if;

        when DIM =>
            if (unsigned(i_data) /= "00000000") then
                next_state <= TMP_STATE;
            else
                next_state <= DONE;
            end if;

        when TMP_STATE =>
            if (counter > 0) then
                next_state <= CYCLE;
            else
                next_state <= END_CYCLE;
            end if;

        when CYCLE =>
            next_state <= UPDATE;

        when UPDATE =>
            next_state <= TMP_STATE;

        when END_CYCLE =>
            next_state <= LOG;

        when LOG =>
            next_state <= SHIFT_STATE;

        when SHIFT_STATE =>
            next_state <= LOAD_ADDRESS;

        when LOAD_ADDRESS =>
            next_state <= LOAD_PIXEL;

        when LOAD_PIXEL =>
            next_state <= TMP_PIXEL;

        when TMP_PIXEL =>
            next_state <= NEW_PIXEL;

        when NEW_PIXEL =>
            next_state <= WRITE;

        when WRITE =>
            if (counter > 1) then
                next_state <= LOAD_ADDRESS;
            else
                next_state <= DONE;
            end if;

        when DONE =>
            if(i_start = '1') then
                next_state <= DONE;
            else
                next_state <= RESET;
            end if;
        end case;
        
    end if;
    end process;
   
   -- Define the output signals
    output_function: process(i_clk)
    begin
    if rising_edge(i_clk) then
        o_en <= '0';
        o_address <= "0000000000000000";
        o_done <= '0';
        o_we <= '0';
        o_data <= "XXXXXXXX";
        
        case curr_state is
        when RESET =>
            pxl <= "XXXXXXXX";
            tmp_pxl <= "XXXXXXXXXXXXXXXX";
            new_pxl <= "XXXXXXXX";
            shift_level <= "XXXX";
            flag <= '1';
            pxl_addr <= "0000000000000010";
            min <= "11111111";
            max <= "00000000";
            if (i_start = '1') then
                o_en <= '1';
            end if;

        when START =>
            o_en <= '1';
            tmp_byte <= unsigned(i_data);
            o_address <= "0000000000000001";

        when DIM =>
            dimension <= unsigned(i_data) * tmp_byte;
            counter <= unsigned(i_data)* tmp_byte;
            address <= "0000000000000001";

        when TMP_STATE =>
            if (counter > 0) then
                tmp_counter <= counter - 1;
                tmp_address <= address + 1;
            else
                tmp_address <= address + 1;
            end if;

        when CYCLE =>
            o_en <= '1';
            counter <= tmp_counter;
            address <= tmp_address;
            o_address <= std_logic_vector(tmp_address);

        when UPDATE =>
            if (unsigned(i_data) < min) then
                min <= unsigned(i_data);
            elsif (unsigned(i_data) > max) then
                max <= unsigned(i_data);
            end if;

        when END_CYCLE =>
            address <= tmp_address;
            delta <= max - min;

        when LOG =>
            if (delta = 255) then
                log_delta <= "1000";
            elsif((delta +1) < 256 and (delta +1) > 127 ) then
                log_delta <= "0111";
            elsif((delta +1) < 128 and (delta +1) > 63) then
                log_delta <= "0110";
            elsif((delta +1) < 64 and (delta +1) > 31) then
                log_delta <= "0101";
            elsif((delta +1) < 32 and (delta +1) > 15) then
                log_delta <= "0100";
            elsif((delta +1) < 16 and (delta +1) > 7) then
                log_delta <= "0011";
            elsif((delta +1) < 8 and (delta +1) > 3) then
                log_delta <= "0010";
            elsif((delta +1) < 4 and (delta +1) > 1) then
                log_delta <= "0001";
            else
                log_delta <= "0000";
            end if;
            counter <= dimension;

        when SHIFT_STATE =>
            o_en <= '1';
            shift_level <= "1000" - log_delta(3 downto 0);
            flag <= '1';

        when LOAD_ADDRESS =>
            o_en <= '1';
            if (flag = '1') then
                w_address <= address;
                o_address <= std_logic_vector(pxl_addr);
            else
                o_address <= std_logic_vector(tmp_address);
                pxl_addr <= tmp_address;
                w_address <= tmp_waddress;
                counter <= tmp_counter;
            end if;

        when LOAD_PIXEL =>
            flag <= '0';
            tmp_counter <= counter - 1;
            tmp_address <= pxl_addr + 1;
            tmp_waddress <= w_address + 1;
            pxl <= unsigned(i_data);

        when TMP_PIXEL =>
            tmp_pxl <= unsigned(shift_left("0000000000000000" + (pxl - min), to_integer(shift_level)));

        when NEW_PIXEL =>
            if tmp_pxl > "0000000011111111" then
                new_pxl <= "11111111";
            else
                new_pxl <= std_logic_vector(tmp_pxl(7 downto 0));
            end if;
            
        when WRITE =>
            o_en <= '1';
            o_we <= '1';
            o_address <= std_logic_vector(w_address);
            o_data <= new_pxl;
            o_address <= std_logic_vector(w_address);

        when DONE =>
            o_done <= '1';
        end case;
        
    end if;
    end process;
    
end FSM;