\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])


   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   //                 
   //m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   //m4_asm(ADDI, x0, x0, 1010)          // Store count of 10 in register 0. (invalid operation)
   //m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   //m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   //m4_asm(ADD, x14, x13, x14)           // Incremental summation
   //m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   //m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // Test result value in x14, and set x31 to reflect pass/fail.
   //m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   //m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   //m4_asm_end()
   //m4_define(['M4_MAX_CYC'], 50)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   m4_test_prog()
   /* verilator lint_on WIDTH */
\TLV
   $reset = *reset;
   
   // PC Logic
   $pc[31:0] = >>1$next_pc; // >>1 is the previous value
   $next_pc[31:0] = $reset ? 0 : $pc + 4; // 4 bytes increment
   
   // Instruction Memory
   `READONLY_MEM($pc, $$instr[31:0]) // instantiation
   //$instr[31:0] = 32'b_0000_0000_0001_0000_0000_0111_0001_0011; // test
   
   // Decoder, opcode[6:2]
   //$is_x_instr = $instr[1:0] == 2'b11; // is always true (in this course)
   $is_u_instr = $instr[6:2] == 5'b00101 || 
                 $instr[6:2] == 5'b01101;
   $is_i_instr = $instr[6:2] == 5'b00000 || 
                 $instr[6:2] == 5'b00001 || 
                 $instr[6:2] == 5'b00100 || 
                 $instr[6:2] == 5'b00110 || 
                 $instr[6:2] == 5'b11001;
   $is_s_instr = $instr[6:2] == 5'b01000 || 
                 $instr[6:2] == 5'b01001; // instructions SB, SH, SW 
   $is_r_instr = $instr[6:2] == 5'b01011 || 
                 $instr[6:2] == 5'b01100 || 
                 $instr[6:2] == 5'b01110 || 
                 $instr[6:2] == 5'b10100;
   $is_b_instr = $instr[6:2] == 5'b11000;
   $is_j_instr = $instr[6:2] == 5'b11011;
   
   // Decoder, instruction fields
   $rd[4:0] = $instr[11:7];
   $funct3[2:0] = $instr[14:12];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   
   // Decoder, instruction valid?
   $is_rd_zero = $instr[11:7] == 0; // to avoid write in register file x0
   $rd_valid = {$is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr} && ~$is_rd_zero;
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
   
   // Decoder, immediate fields (produced by the instructions)
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } : 
                $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } : 
                $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } : 
                $is_u_instr ? { $instr[31:12], 12'b0 } : 
                $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } : 
                32'b0;
   
   // Decoder, determine specific instructions
   $funct3[2:0] = $funct3_valid ? $instr[14:12] : 3'b0;
   $opcode[6:0] = $instr[6:0];
   $dec_bits[10:0] = {$instr[30], $funct3, $opcode}; // concatenate relevant fields
   
   // Decoder, instructions added in Chapter 4
   $is_beq = $dec_bits ==? 11'bx_000_1100011;
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add = $dec_bits ==? 11'b0_000_0110011;
   
   // Decoder, instructions added in Chapter 5
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr = $dec_bits ==? 11'bx_000_1100111;
   $is_slti = $dec_bits ==? 11'bx_010_001_0011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori = $dec_bits ==? 11'bx_100_0010011;
   $is_ori = $dec_bits ==? 11'bx_110_0010011;
   $is_andi = $dec_bits ==? 11'bx_111_0010011;
   $is_slli = $dec_bits ==? 11'b0_001_0010011;
   $is_srli = $dec_bits ==? 11'b0_101_0010011;
   $is_srai = $dec_bits ==? 11'b1_101_0010011;
   $is_sub = $dec_bits ==? 11'b1_000_0110011;
   $is_sll = $dec_bits ==? 11'b0_001_0110011;
   $is_slt = $dec_bits ==? 11'b0_010_0110011;
   $is_sltu = $dec_bits ==? 11'b0_011_0110011;
   $is_xor = $dec_bits ==? 11'b0_100_0110011;
   $is_srl = $dec_bits ==? 11'b0_101_0110011;
   $is_sra = $dec_bits ==? 11'b1_101_0110011;
   $is_or = $dec_bits ==? 11'b0_110_0110011;
   $is_and = $dec_bits ==? 11'b0_111_0110011;
   $is_load = $dec_bits ==? 11'bx_xxx_0000011; // instructions LB, LH, LW, LBU, LHU
   
   // Subexpressions needed by the ALU
   // SLTU and SLTI (set of less than, unsigned) results:
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   // SRA and SRAI (shift right, arithmetic) results:
   // sign-extended src1
   $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value };
   // 64-bit sign-extended results, to be truncated
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
   
   // Address Logic
   $addr[31:0] = {27'b0, $rs1} + $imm;
   
   // Arithmetic Logic Unit (ALU)
   $result[31:0] = $is_addi ? $src1_value + $imm : 
                   $is_add  ? $src1_value + $src2_value : 
                   $is_andi ? $src1_value & $imm : 
                   $is_ori ? $src1_value | $imm : 
                   $is_xori ? $src1_value ^ $imm : 
                   $is_slli ? $src1_value << $imm[5:0] : 
                   $is_srli ? $src1_value >> $imm[5:0] : 
                   $is_and ? $src1_value & $src2_value : 
                   $is_or ? $src1_value | $src2_value : 
                   $is_xor ? $src1_value ^ $src2_value : 
                   $is_add ? $src1_value + $src2_value : 
                   $is_sub ? $src1_value - $src2_value :
                   $is_sll ? $src1_value << $src2_value[4:0] : 
                   $is_srl ? $src1_value >> $src2_value[4:0] : 
                   $is_sltu ? $sltu_rslt : 
                   $is_sltiu ? $sltiu_rslt : 
                   $is_lui ? {$imm[31:12], 12'b0} : 
                   $is_auipc ? $pc + $imm : 
                   $is_jal ? $pc + 32'd4 : 
                   $is_jalr ? $pc + 32'd4 : 
                   $is_slt ? ( ($src1_value[31] == $src2_value[31]) ? 
                                   $sltu_rslt : 
                                   {31'b0, $src1_value[31]} ) : 
                   $is_slti ? ( ($src1_value[31] == $imm[31]) ? 
                                   $sltiu_rslt : 
                                   {31'b0, $src1_value[31]} ) : 
                   $is_sra ? $sra_rslt[31:0] : 
                   $is_srai ? $srai_rslt[31:0] : 
                   $is_load ? $addr : 
                   $is_s_instr ? $addr : 
                   32'b0;
   
   // Branch Logic
   $taken_br = { $is_beq && {$src1_value == $src2_value} } || 
               { $is_bne && {$src1_value != $src2_value} } || 
               { $is_blt && {($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])} } || 
               { $is_bge && {($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])} } || 
               { $is_bltu && {$src1_value < $src2_value} } || 
               { $is_bgeu && {$src1_value >= $src2_value} } || 
               1'b0;
   
   // target PC of the branch/jump instruction
   $br_tgt_pc[31:0] = $pc + $imm;
   $jalr_tgt_pc[31:0] = $src1_value + $imm;
   $next_pc[31:0] = $taken_br ? $br_tgt_pc[31:0] :  // branch inst
                    $is_jal ? $br_tgt_pc[31:0] :  // jump inst
                    $is_jalr ? $jalr_tgt_pc[31:0] :  // jump inst
                    $next_pc;
   
   // last multiplexer
   $mux_result[31:0] = $is_load ? $ld_data : $result; 
   
   // Supress LOG warnings
   `BOGUS_USE($rd $rd_valid $rs1 $rs1_valid $rs2 $rs2_valid $funct3 $funct3_valid $imm_valid
              $is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu $is_addi $is_add)
   
   // Assert these to end simulation (before Makerchip cycle limit).
   //*passed = 1'b0;
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   m4+rf(32, 32, $reset, $rd_valid, $rd[4:0], $mux_result[31:0], $rs1_valid, $rs1[4:0], $src1_value, $rs2_valid, $rs2[4:0], $src2_value)
   m4+dmem(  32, 32, $reset, $result[4:0], $is_s_instr, $src2_value,    $is_load, $ld_data)
   //m4+dmem(32, 32, $reset, $addr[4:0],   $wr_en,      $wr_data[31:0], $rd_en,   $rd_data)
   m4+cpu_viz()
\SV
   endmodule