-- Copyright 2003 J�r�mie Detrey, Florent de Dinechin
--
-- This file is part of FPLibrary
--
-- FPLibrary is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- FPLibrary is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with FPLibrary; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library fplib;
use fplib.pkg_fpmul.all;
use fplib.pkg_misc.all;
use fplib.pkg_fp_misc.all;

entity FPMul_Clk is
  generic ( wE : positive := 8;
            wF : positive := 23 );
  port ( nA  : in  std_logic_vector(wE+wF+2 downto 0);
         nB  : in  std_logic_vector(wE+wF+2 downto 0);
         nR  : out std_logic_vector(wE+wF+2 downto 0);
         clk : in  std_logic );
end entity;

architecture arch of FPMul_Clk is
  signal nA_1  : std_logic_vector(wE+wF+2 downto 0);
  signal nB_1  : std_logic_vector(wE+wF+2 downto 0);

  signal fA0_1  : std_logic_vector(wF downto 0);
  signal fB0_1  : std_logic_vector(wF downto 0);

  signal eRn0_1  : std_logic_vector(wE downto 0);
  signal eRn0_11 : std_logic_vector(wE downto 0);
  signal fRn0_10 : std_logic_vector(2*wF+1 downto 0);
  signal fRn0_11 : std_logic_vector(2*wF+1 downto 0);
  signal eRn1_11 : std_logic_vector(wE downto 0);
  signal fRn1_11 : std_logic_vector(wF+2 downto 0);
  signal sRn_1   : std_logic;
  signal sRn_12  : std_logic;
  signal eRn_11  : std_logic_vector(wE downto 0);
  signal eRn_12  : std_logic_vector(wE downto 0);
  signal fRn_11  : std_logic_vector(wF downto 0);
  signal fRn_12  : std_logic_vector(wF downto 0);
  signal nRn_12  : std_logic_vector(wE+wF+2 downto 0);

  signal sticky_11 : std_logic;

  signal xA_1   : std_logic_vector(1 downto 0);
  signal xB_1   : std_logic_vector(1 downto 0);
  signal xAB_1  : std_logic_vector(3 downto 0);
  signal xAB_12 : std_logic_vector(3 downto 0);
  
  signal nR_12 : std_logic_vector(wE+wF+2 downto 0);
begin
  nA_1 <= nA;
  nB_1 <= nB;
  
  fA0_1 <= "1" & nA_1(wF-1 downto 0);
  fB0_1 <= "1" & nB_1(wF-1 downto 0);

  product : FPMul_Product_Clk
    generic map ( wF => wF )
    port map ( fA  => fA0_1,
               fB  => fB0_1, ---------------------------------------------------
               fR  => fRn0_10, -------------------------------------------------
               clk => clk);

  eRn0_1 <= ("0" & nA_1(wE+wF-1 downto wF)) + ("0" & nB_1(wE+wF-1 downto wF));

  ern0_delay : Delay
    generic map ( w => wE+1,
                  n => prodLatency(wF)+1 )
    port map ( input  => eRn0_1, -----------------------------------------------
               output => eRn0_11, ----------------------------------------------
               clk    => clk );

  process(clk)
  begin
    if clk'event and clk='1' then
      fRn0_11 <= fRn0_10;
    end if;
  end process;
        
--------------------------------------------------------------------------------

  with fRn0_11(2*wF+1) select
    fRn1_11(wF+2 downto 1) <= fRn0_11(2*wF+1 downto wF) when '1',
                                 fRn0_11(2*wF downto wF-1) when others;
  eRn1_11 <= eRn0_11 - ("00" & (wE-2 downto 1 => '1') & (not fRn0_11(2*wF+1)));
  
  sticky_11 <= '0' when fRn0_11(wF-2 downto 0) = (wF-2 downto 0 => '0') else '1';
  fRn1_11(0) <= sticky_11 or (fRn0_11(2*wF+1) and fRn0_11(wF-1));

  eRn1_11 <= eRn0_11 - ("00" & (wE-2 downto 1 => '1') & (not fRn0_11(2*wF+1)));
  round : FP_Round
    generic map ( wE => wE,
                  wF => wF )
    port map ( eA => eRn1_11,
               fA => fRn1_11,
               eR => eRn_11,
               fR => fRn_11 );

  sRn_1 <= nA_1(wE+wF) xor nB_1(wE+wF);

  srn_delay : Delay
    generic map ( w => 1,
                  n => prodLatency(wF)+2 )
    port map ( input(0)  => sRn_1, ---------------------------------------------
               output(0) => sRn_12, --------------------------------------------
               clk       => clk );

  process(clk)
  begin
    if clk'event and clk='1' then
      eRn_12 <= eRn_11;
      fRn_12 <= fRn_11;
    end if;
  end process;
  
--------------------------------------------------------------------------------

  format : FP_Format
    generic map ( wE => wE,
                  wF => wF )
    port map ( sA => sRn_12,
               eA => eRn_12,
               fA => fRn_12,
               nR => nRn_12 );
  
  xA_1 <= nA_1(wE+wF+2 downto wE+wF+1);
  xB_1 <= nB_1(wE+wF+2 downto wE+wF+1);
  xAB_1 <= xA_1 & xB_1 when xA_1 >= xB_1 else
            xB_1 & xA_1;

  xab_delay : Delay
    generic map ( w => 4,
                  n => prodLatency(wF)+2 )
    port map ( input  => xAB_1, ------------------------------------------------
               output => xAB_12, -----------------------------------------------
               clk    => clk );

  with xAB_12 select
    nR_12(wE+wF+2 downto wE+wF+1) <= nRn_12(wE+wF+2 downto wE+wF+1) when "0101",
                                               "00"                                     when "0000" | "0100",
                                               "10"                                     when "1001" | "1010",
                                               "11"                                     when others;

  nR_12(wE+wF downto 0) <= nRn_12(wE+wF downto 0);

  nR <= nR_12;
end architecture;