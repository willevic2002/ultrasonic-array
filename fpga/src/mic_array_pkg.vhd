-- mic_array_pkg: gemensamma typer för signalkedjan. Se docs/pipeline.md.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mic_array_pkg is
  constant N_CH : positive := 16;  -- kanal 2k = bit_r på pdm_data[k], 2k+1 = bit_f
  type sample_array is array (0 to N_CH - 1) of signed(15 downto 0);
end package;
