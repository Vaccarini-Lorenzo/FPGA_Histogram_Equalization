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

architecture Behavioral of project_reti_logiche is

    type state_type is (RESET, START, DIM, CYCLE, UPDATE, SHIFT_LVL, LOAD_ADDRESS, LOAD_PIXEL, NEW_PIXEL, WRITE, DONE);
    signal curr_state, next_state: state_type;
    signal tmp_byte, min, max: unsigned (7 downto 0);
    signal shift_level: unsigned (3 downto 0);
    signal tmp_pxl: unsigned (15 downto 0);
    signal pxl_addr: unsigned (15 downto 0);
    signal r_address, next_r_address, w_address, next_w_address, counter, next_counter, dimension: unsigned(15 downto 0);
    signal new_pxl: std_logic_vector(7 downto 0);
    signal first_pixel_flag: std_logic;

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
    lambda: process(i_clk)
    begin
    if falling_edge(i_clk) then
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
                next_state <= CYCLE;
            else
                next_state <= DONE;
            end if;

        when CYCLE =>
            if (counter > 0) then
                next_state <= UPDATE;
            else
                next_state <= SHIFT_LVL;
            end if;

        when UPDATE =>
            next_state <= CYCLE;

        when SHIFT_LVL =>
            next_state <= LOAD_ADDRESS;

        when LOAD_ADDRESS =>
            next_state <= LOAD_PIXEL;

        when LOAD_PIXEL =>
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
    
    -- Define output and internal signals
    delta: process(i_clk)
    begin
    if falling_edge(i_clk) then
        o_en <= '0';
        o_address <= "0000000000000000";
        o_done <= '0';
        o_we <= '0';
        o_data <= "XXXXXXXX";
        
        case curr_state is
        when RESET =>
            first_pixel_flag <= '1';
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
            r_address <= "0000000000000001";

        when CYCLE =>
            if (counter > 0) then
                o_en <= '1';
                o_address <= std_logic_vector(r_address + 1);
                next_counter <= counter - 1;
                next_r_address <= r_address + 1;
            else
                next_r_address <= r_address + 1;
            end if;

        when UPDATE =>
            counter <= next_counter;
            r_address <= next_r_address;
            if (unsigned(i_data) < min) then
                min <= unsigned(i_data);
            elsif (unsigned(i_data) > max) then
                max <= unsigned(i_data);
            end if;
            
        when SHIFT_LVL =>
            -- Computing shift level
            if (max - min = 255) then
                shift_level <= "0000";
            elsif((max - min +1) < 256 and (max - min +1) > 127 ) then
                shift_level <= "0001";
            elsif((max - min +1) < 128 and (max - min +1) > 63) then
                shift_level <= "0010";
            elsif((max - min +1) < 64 and (max - min +1) > 31) then
                shift_level <= "0011";
            elsif((max - min +1) < 32 and (max - min +1) > 15) then
                shift_level <= "0100";
            elsif((max - min +1) < 16 and (max - min +1) > 7) then
                shift_level <= "0101";
            elsif((max - min +1) < 8 and (max - min +1) > 3) then
                shift_level <= "0110";
            elsif((max - min +1) < 4 and (max - min +1) > 1) then
                shift_level <= "0111";
            else
                shift_level <= "1000";
            end if;
            
            r_address <= next_r_address;
            counter <= dimension;
            o_en <= '1';
            
        when LOAD_ADDRESS =>
            o_en <= '1';
            if (first_pixel_flag = '1') then
                w_address <= r_address;
                o_address <= std_logic_vector(pxl_addr);
            else
                o_address <= std_logic_vector(next_r_address);
                pxl_addr <= next_r_address;
                w_address <= next_w_address;
                counter <= next_counter;
            end if;

        when LOAD_PIXEL =>
            first_pixel_flag <= '0';
            next_counter <= counter - 1;
            next_r_address <= pxl_addr + 1;
            next_w_address <= w_address + 1;
            -- Reading the pixel from i_data and computing the equalized version
            tmp_pxl <= unsigned(shift_left("0000000000000000" + (unsigned(i_data) - min), to_integer(shift_level)));

        when NEW_PIXEL =>
            -- Managing possible > 255 values
            if tmp_pxl > "0000000011111111" then
                new_pxl <= "11111111";
            else
                new_pxl <= std_logic_vector(tmp_pxl(7 downto 0));
            end if;
            
        when WRITE =>
            o_en <= '1';
            o_we <= '1';
            o_data <= new_pxl;
            o_address <= std_logic_vector(w_address);

        when DONE =>
            o_done <= '1';
        end case;
        
    end if;
    end process;
    
end Behavioral;