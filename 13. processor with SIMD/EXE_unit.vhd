library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity EXE_unit is
    port (
        clk : in std_logic;
        res_and_stall : in control;
        operands_from_ID: in operand_type;
        decoded_instr_from_ID : in instruction_decoded;
                
        branch_to_IF : out branch;
        load_to_MEM : out std_logic;
        store_to_MEM : out std_logic;
        
        data_to_MEM : out Tvector;
        adr_to_MEM : out Tadr;
        idx_d_to_MEM : out Tidx;
        data_valid_flag_for_WB : out std_logic;
        wb_forwarded_from_EXE : in write_back;          --forwarded data from exe
        wb_forwarded_from_MEM : in write_back          --forwarded data from mem            
        );
end entity EXE_unit;

architecture behaviour of EXE_unit is
  component ALU is
    port (
      A : in Tdata;
      B : in Tdata;
      S : in std_logic_vector(2 downto 0);
      
      Q : out Tdata;
      Z_OUT : out std_logic
      
    );
  end component ALU;
   
  signal A_internal, B_internal, Q_internal, loadi_result, I_internal, data_to_MEM_temp, pc_call, perm_result, tge, tse, rdc8 : Tvector;
  signal S_internal_0, S_internal_1, S_internal_2, S_internal_3 : std_logic_vector(2 downto 0);
  signal Z_OUT_internal : std_logic_vector(3 downto 0);  
  signal load_to_MEM_temp : std_logic := '0';
  signal store_to_MEM_temp : std_logic := '0'; 
  signal adr_to_MEM_temp : Tadr;
  signal idx_d_to_MEM_temp : Tidx;
  signal data_valid_flag_for_WB_temp : std_logic := '0';
  signal branch_target : Tadr;
  signal operands_b, operands_a : Tvector;
  signal not_zero, zero : std_logic;
  signal mult32 : Tvector;
  signal mult64_0, mult64_1, mult64_2, mult64_3 : std_logic_vector(63 downto 0);
    
begin
  
  ALU_unit_0 : ALU
    port map (
      A => A_internal(0),
      B => B_internal(0),
      S => S_internal_0,     
      Q => Q_internal(0),
      Z_OUT => Z_OUT_internal(0)
    );
     
  ALU_unit_1 : ALU
    port map (
      A => A_internal(1),
      B => B_internal(1),
      S => S_internal_1,     
      Q => Q_internal(1),
      Z_OUT => Z_OUT_internal(1)
    );
     
  ALU_unit_2 : ALU
    port map (
      A => A_internal(2),
      B => B_internal(2),
      S => S_internal_2,     
      Q => Q_internal(2),
      Z_OUT => Z_OUT_internal(2)
    );
     
  ALU_unit_3 : ALU
    port map (
      A => A_internal(3),
      B => B_internal(3),
      S => S_internal_3,     
      Q => Q_internal(3),
      Z_OUT => Z_OUT_internal(3)
    );

--*****************************************************forwarding*********************************************************************  
  operands_a <= wb_forwarded_from_EXE.d when (wb_forwarded_from_EXE.d_valid = '1' and (decoded_instr_from_ID.idx_a = wb_forwarded_from_EXE.idx_d)) else
                        wb_forwarded_from_MEM.d when (wb_forwarded_from_MEM.d_valid = '1' and (decoded_instr_from_ID.idx_a = wb_forwarded_from_MEM.idx_d)) else
                        operands_from_ID.a;            
  operands_b <= wb_forwarded_from_EXE.d when (wb_forwarded_from_EXE.d_valid = '1' and (decoded_instr_from_ID.idx_b = wb_forwarded_from_EXE.idx_d)) else
                        wb_forwarded_from_MEM.d when (wb_forwarded_from_MEM.d_valid = '1' and (decoded_instr_from_ID.idx_b = wb_forwarded_from_MEM.idx_d)) else
                        operands_from_ID.b;
----------------------------------------------------------------------------------------------------------------------------------------
    
--****************************************************************multiplier********************************************************************************
  mult64_0 <= operands_a(0) * operands_b(0);
  mult32(0) <= mult64_0(31 downto 0);
  mult64_1 <= operands_a(1) * operands_b(1);
  mult32(1) <= mult64_1(31 downto 0);
  mult64_2 <= operands_a(2) * operands_b(2);
  mult32(2) <= mult64_2(31 downto 0);
  mult64_3 <= operands_a(3) * operands_b(3);
  mult32(3) <= mult64_3(31 downto 0);
------------------------------------------------------------------------------------------------------------------------------------------------------------  
--****************************************************************loadi for simd**************************************************************************--
  loadi_result(0)(31 downto 16) <= operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                            and decoded_instr_from_ID.mask(0) = '0' else
                                   operands_a(0)(31 downto 16) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                                        and decoded_instr_from_ID.mask(0) = '0' else
                                   operands_a(0)(31 downto 16);
  loadi_result(0)(15 downto 0) <= operands_a(0)(15 downto 0) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                                          and decoded_instr_from_ID.mask(0) = '0' else
                                  operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                        and decoded_instr_from_ID.mask(0) = '0' else
                                  operands_a(0)(15 downto 0);
----------------                                  
  loadi_result(1)(31 downto 16) <= operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                            and decoded_instr_from_ID.mask(1) = '0' else
                                   operands_a(1)(31 downto 16) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                                        and decoded_instr_from_ID.mask(1) = '0' else
                                   operands_a(1)(31 downto 16);
  loadi_result(1)(15 downto 0) <= operands_a(1)(15 downto 0) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                                          and decoded_instr_from_ID.mask(1) = '0' else
                                  operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                        and decoded_instr_from_ID.mask(1) = '0' else
                                  operands_a(1)(15 downto 0);
----------------                                  
  loadi_result(2)(31 downto 16) <= operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                            and decoded_instr_from_ID.mask(2) = '0' else
                                   operands_a(2)(31 downto 16) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                                        and decoded_instr_from_ID.mask(2) = '0' else
                                   operands_a(2)(31 downto 16);
  loadi_result(2)(15 downto 0) <= operands_a(2)(15 downto 0) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                                          and decoded_instr_from_ID.mask(2) = '0' else
                                  operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                        and decoded_instr_from_ID.mask(2) = '0' else
                                  operands_a(2)(15 downto 0);
----------------                                  
  loadi_result(3)(31 downto 16) <= operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                            and decoded_instr_from_ID.mask(3) = '0' else
                                   operands_a(3)(31 downto 16) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                                        and decoded_instr_from_ID.mask(3) = '0' else
                                   operands_a(3)(31 downto 16);
  loadi_result(3)(15 downto 0) <= operands_a(3)(15 downto 0) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' 
                                                                          and decoded_instr_from_ID.mask(3) = '0' else
                                  operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' 
                                                        and decoded_instr_from_ID.mask(3) = '0' else
                                  operands_a(3)(15 downto 0);
-------------------------------------------------------------------------------------------------------------------------------------------------------------  


--*******************************************************ALU Conrol********************************************************************
  I_internal(0) <= std_logic_vector( resize(signed(operands_from_ID.i), 32) );
  I_internal(1) <= std_logic_vector( resize(signed(operands_from_ID.i), 32) );
  I_internal(2) <= std_logic_vector( resize(signed(operands_from_ID.i), 32) );
  I_internal(3) <= std_logic_vector( resize(signed(operands_from_ID.i), 32) );
 
  ------ALU_0
  A_internal(0) <= operands_a(0);              
  B_internal(0) <= std_logic_vector(signed(I_internal(0))) when decoded_instr_from_ID.load = '1' or decoded_instr_from_ID.store = '1' else
                std_logic_vector(signed(I_internal(0))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                std_logic_vector(signed(I_internal(0))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(0))) >= 0 else
                std_logic_vector(signed((not I_internal(0)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(0))) < 0 else
                std_logic_vector(signed((not operands_b(0)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(0))) < 0 else
                std_logic_vector(signed((not operands_b(0)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(0))) < 0 else
                operands_b(0); 
  S_internal_0 <= "000" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(0))) >= 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(0))) < 0 else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(0))) < 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(0))) < 0 else
                "001" when decoded_instr_from_ID.alu = '1' and (decoded_instr_from_ID.alu_op = "1100" or decoded_instr_from_ID.alu_op = "1101") else   --tge/tse
                decoded_instr_from_ID.alu_op(2 downto 0) when decoded_instr_from_ID.alu = '1' else
                "000";
 
  ------ALU_1
  A_internal(1) <= operands_a(1);              
  B_internal(1) <= std_logic_vector(signed(I_internal(1))) when decoded_instr_from_ID.load = '1' or decoded_instr_from_ID.store = '1' else
                std_logic_vector(signed(I_internal(1))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                std_logic_vector(signed(I_internal(1))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(1))) >= 0 else
                std_logic_vector(signed((not I_internal(1)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(1))) < 0 else
                std_logic_vector(signed((not operands_b(1)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(1))) < 0 else
                std_logic_vector(signed((not operands_b(1)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(1))) < 0 else
                operands_b(1); 
  S_internal_1 <= "000" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(1))) >= 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(1))) < 0 else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(1))) < 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(1))) < 0 else
                "001" when decoded_instr_from_ID.alu = '1' and (decoded_instr_from_ID.alu_op = "1100" or decoded_instr_from_ID.alu_op = "1101") else   --tge/tse
                decoded_instr_from_ID.alu_op(2 downto 0) when decoded_instr_from_ID.alu = '1' else
                "000";
                
  ------ALU_2
  A_internal(2) <= operands_a(2);              
  B_internal(2) <= std_logic_vector(signed(I_internal(2))) when decoded_instr_from_ID.load = '1' or decoded_instr_from_ID.store = '1' else
                std_logic_vector(signed(I_internal(2))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                std_logic_vector(signed(I_internal(2))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(2))) >= 0 else
                std_logic_vector(signed((not I_internal(2)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(2))) < 0 else
                std_logic_vector(signed((not operands_b(2)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(2))) < 0 else
                std_logic_vector(signed((not operands_b(2)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(2))) < 0 else
                operands_b(2); 
  S_internal_2 <= "000" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(2))) >= 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(2))) < 0 else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(2))) < 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(2))) < 0 else
                "001" when decoded_instr_from_ID.alu = '1' and (decoded_instr_from_ID.alu_op = "1100" or decoded_instr_from_ID.alu_op = "1101") else   --tge/tse
                decoded_instr_from_ID.alu_op(2 downto 0) when decoded_instr_from_ID.alu = '1' else
                "000";
                
  -------ALU_3
  A_internal(3) <= operands_a(3);              
  B_internal(3) <= std_logic_vector(signed(I_internal(3))) when decoded_instr_from_ID.load = '1' or decoded_instr_from_ID.store = '1' else
                std_logic_vector(signed(I_internal(3))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                std_logic_vector(signed(I_internal(3))) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(3))) >= 0 else
                std_logic_vector(signed((not I_internal(3)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(3))) < 0 else
                std_logic_vector(signed((not operands_b(3)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(3))) < 0 else
                std_logic_vector(signed((not operands_b(3)) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(3))) < 0 else
                operands_b(3); 
  S_internal_3 <= "000" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(3))) >= 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal(3))) < 0 else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b(3))) < 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b(3))) < 0 else
                "001" when decoded_instr_from_ID.alu = '1' and (decoded_instr_from_ID.alu_op = "1100" or decoded_instr_from_ID.alu_op = "1101") else   --tge/tse
                decoded_instr_from_ID.alu_op(2 downto 0) when decoded_instr_from_ID.alu = '1' else
                "000";
  ------------------------------------------------------------------------------------------------------------------------------------------

  load_to_MEM_temp <= '1' when decoded_instr_from_ID.load = '1' else
                      '0';
  
  store_to_MEM_temp <= '1' when decoded_instr_from_ID.store = '1' else
                       '0';
  
  adr_to_MEM_temp <= Q_internal(0) when decoded_instr_from_ID.load = '1' or decoded_instr_from_ID.store = '1';
                     
  data_to_MEM_temp <= Q_internal when decoded_instr_from_ID.alu = '1' and not(decoded_instr_from_ID.perm = '1' or
                                                                              decoded_instr_from_ID.tge = '1'  or
                                                                              decoded_instr_from_ID.tse = '1' or
                                                                              decoded_instr_from_ID.rdc8 = '1' or
                                                                              decoded_instr_from_ID.mul = '1') else
                      operands_b when decoded_instr_from_ID.store = '1' else
                      loadi_result when decoded_instr_from_ID.loadi = '1' else
                      pc_call when decoded_instr_from_ID.call = '1' else
                      perm_result when decoded_instr_from_ID.perm = '1' else
                      tge when decoded_instr_from_ID.tge = '1' else
                      tse when decoded_instr_from_ID.tse = '1' else
                      rdc8 when decoded_instr_from_ID.rdc8 = '1' else
                      mult32 when decoded_instr_from_ID.mul = '1' else
                      init_vector;
                      
  pc_call(0) <= decoded_instr_from_ID.instr.pc + 4;
  pc_call(1) <= decoded_instr_from_ID.instr.pc + 4;
  pc_call(2) <= decoded_instr_from_ID.instr.pc + 4;
  pc_call(3) <= decoded_instr_from_ID.instr.pc + 4;        
  
  idx_d_to_MEM_temp <= decoded_instr_from_ID.idx_d;
                       
  data_valid_flag_for_WB_temp <= '1' when decoded_instr_from_ID.alu = '1' or decoded_instr_from_ID.loadi = '1' or decoded_instr_from_ID.call = '1' 
                                          or decoded_instr_from_ID.perm = '1' or decoded_instr_from_ID.tge = '1'or decoded_instr_from_ID.tse = '1'
                                          or decoded_instr_from_ID.rdc8 = '1' or decoded_instr_from_ID.mul = '1' else
                                 '0';
 --****************************************************branching******************************************************************                                
  zero <= (decoded_instr_from_ID.mask(0) or active_high(operands_a(0)=x"00000000")) and 
          (decoded_instr_from_ID.mask(1) or active_high(operands_a(1)=x"00000000")) and 
          (decoded_instr_from_ID.mask(2) or active_high(operands_a(2)=x"00000000")) and 
          (decoded_instr_from_ID.mask(3) or active_high(operands_a(3)=x"00000000"));
  not_zero <= (decoded_instr_from_ID.mask(0) or active_high( operands_a(0)/=x"00000000")) and 
              (decoded_instr_from_ID.mask(1) or active_high(operands_a(1)/=x"00000000")) and 
              (decoded_instr_from_ID.mask(2) or active_high(operands_a(2)/=x"00000000")) and 
              (decoded_instr_from_ID.mask(3) or active_high(operands_a(3)/=x"00000000"));
  branch_to_IF.branch <= '1' when (decoded_instr_from_ID.jmp = '1' 
                                  or (decoded_instr_from_ID.jz = '1' and zero = '1')
                                  or (decoded_instr_from_ID.jnz = '1' and not_zero = '1') 
                                  or decoded_instr_from_ID.call = '1') and decoded_instr_from_ID.instr.valid = '1' else
                         '0';                       
  branch_target <= decoded_instr_from_ID.instr.pc + std_logic_vector(shift_left(unsigned(I_internal(0)),2)); 
  branch_to_IF.target <= branch_target when decoded_instr_from_ID.relative = '1' else
                      operands_a(0);
  --------------------------------------------------------------------------------------------------------------------------------
  --******************************************perm instr***************************************************************
  perm_result(0) <= operands_a(to_integer(unsigned(operands_from_ID.i(1 downto 0))));
  perm_result(1) <= operands_a(to_integer(unsigned(operands_from_ID.i(3 downto 2))));
  perm_result(2) <= operands_a(to_integer(unsigned(operands_from_ID.i(5 downto 4))));
  perm_result(3) <= operands_a(to_integer(unsigned(operands_from_ID.i(7 downto 6))));
  ---------------------------------------------------------------------------------------------------------------------
  
  --****************************************tge / tse******************************************************************
  tge(0) <= (others=>'0') when Q_internal(0)(31) = '1' else
                std_logic_vector(to_signed(1,32));
  tge(1) <= (others=>'0') when Q_internal(1)(31) = '1' else
                std_logic_vector(to_signed(1,32));
  tge(2) <= (others=>'0') when Q_internal(2)(31) = '1' else
                std_logic_vector(to_signed(1,32));
  tge(3) <= (others=>'0') when Q_internal(3)(31) = '1' else
                std_logic_vector(to_signed(1,32));
                
  tse(0) <= std_logic_vector(to_signed(1,32)) when Q_internal(0) = x"00000000" else
                (others=>'0') when Q_internal(0)(31) = '0' else
                std_logic_vector(to_signed(1,32));
  tse(1) <= std_logic_vector(to_signed(1,32)) when Q_internal(1) = x"00000000" else
              (others=>'0') when Q_internal(1)(31) = '0' else
                std_logic_vector(to_signed(1,32));
  tse(2) <= std_logic_vector(to_signed(1,32)) when Q_internal(2) = x"00000000" else
                (others=>'0') when Q_internal(2)(31) = '0' else
                std_logic_vector(to_signed(1,32));
  tse(3) <= std_logic_vector(to_signed(1,32)) when Q_internal(3) = x"00000000" else
              (others=>'0') when Q_internal(3)(31) = '0' else
                std_logic_vector(to_signed(1,32));
                
  ---------------------------------------------------------------------------------------------------------------------
  --*********************************************rdc8*******************************************************************
  rdc8(0)(7 downto 0) <= operands_a(0)(7 downto 0); 
  rdc8(0)(15 downto 8) <= operands_a(1)(7 downto 0);
  rdc8(0)(23 downto 16) <= operands_a(2)(7 downto 0);
  rdc8(0)(31 downto 24) <= operands_a(3)(7 downto 0);
  
  rdc8(1) <= (others=>'0');
  rdc8(2) <= (others=>'0');
  rdc8(3) <= (others=>'0');
  ----------------------------------------------------------------------------------------------------------------------                
                         
  clocked_process : process(clk)
  begin
    if rising_edge (clk) then 
      if res_and_stall.res = '1' then
          
        load_to_MEM <= '0';
        store_to_MEM <= '0';
        data_valid_flag_for_WB <= '0';
          
      elsif res_and_stall.stall = '0' then
        
        if decoded_instr_from_ID.instr.valid = '1' then
        load_to_MEM <= load_to_MEM_temp;
        store_to_MEM <= store_to_MEM_temp;  
        data_valid_flag_for_WB <= data_valid_flag_for_WB_temp;
        else
        load_to_MEM <= '0';
        store_to_MEM <= '0';  
        data_valid_flag_for_WB <= '0';
        end if;           
         
        adr_to_MEM <= adr_to_MEM_temp;
        data_to_MEM <= data_to_MEM_temp; 
        idx_d_to_MEM <= idx_d_to_MEM_temp; 
             
      end if;
    end if;
  end process;                                                                           
end architecture behaviour;
