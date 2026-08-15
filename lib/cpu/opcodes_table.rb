# lib/cpu/opcodes_table.rb

module OpcodesTable
  # Format : [instruction_symbol, addressing_mode_symbol, base_cycles]
  #
  # Modes :
  #   :imp  = Implicit        :acc = Accumulator
  #   :imm  = Immediate       :zp  = Zero Page
  #   :zpx  = Zero Page,X     :zpy = Zero Page,Y
  #   :abs  = Absolute         :abx = Absolute,X
  #   :aby  = Absolute,Y       :ind = Indirect
  #   :izx  = (Indirect,X)     :izy = (Indirect),Y
  #   :rel  = Relative

  OPCODES = {
    # ===== Chargement / Stockage =====
    # LDA
    0xA9 => [:lda, :imm, 2],
    0xA5 => [:lda, :zp,  3],
    0xB5 => [:lda, :zpx, 4],
    0xAD => [:lda, :abs, 4],
    0xBD => [:lda, :abx, 4],
    0xB9 => [:lda, :aby, 4],
    0xA1 => [:lda, :izx, 6],
    0xB1 => [:lda, :izy, 5],

    # LDX
    0xA2 => [:ldx, :imm, 2],
    0xA6 => [:ldx, :zp,  3],
    0xB6 => [:ldx, :zpy, 4],
    0xAE => [:ldx, :abs, 4],
    0xBE => [:ldx, :aby, 4],

    # LDY
    0xA0 => [:ldy, :imm, 2],
    0xA4 => [:ldy, :zp,  3],
    0xB4 => [:ldy, :zpx, 4],
    0xAC => [:ldy, :abs, 4],
    0xBC => [:ldy, :abx, 4],

    # STA
    0x85 => [:sta, :zp,  3],
    0x95 => [:sta, :zpx, 4],
    0x8D => [:sta, :abs, 4],
    0x9D => [:sta, :abx, 5],
    0x99 => [:sta, :aby, 5],
    0x81 => [:sta, :izx, 6],
    0x91 => [:sta, :izy, 6],

    # STX
    0x86 => [:stx, :zp,  3],
    0x96 => [:stx, :zpy, 4],
    0x8E => [:stx, :abs, 4],

    # STY
    0x84 => [:sty, :zp,  3],
    0x94 => [:sty, :zpx, 4],
    0x8C => [:sty, :abs, 4],

    # ===== Transferts de registres =====
    0xAA => [:tax, :imp, 2],
    0xA8 => [:tay, :imp, 2],
    0x8A => [:txa, :imp, 2],
    0x98 => [:tya, :imp, 2],
    0xBA => [:tsx, :imp, 2],
    0x9A => [:txs, :imp, 2],

    # ===== Stack =====
    0x48 => [:pha, :imp, 3],
    0x68 => [:pla, :imp, 4],
    0x08 => [:php, :imp, 3],
    0x28 => [:plp, :imp, 4],

    # ===== Arithmétique =====
    # ADC
    0x69 => [:adc, :imm, 2],
    0x65 => [:adc, :zp,  3],
    0x75 => [:adc, :zpx, 4],
    0x6D => [:adc, :abs, 4],
    0x7D => [:adc, :abx, 4],
    0x79 => [:adc, :aby, 4],
    0x61 => [:adc, :izx, 6],
    0x71 => [:adc, :izy, 5],

    # SBC
    0xE9 => [:sbc, :imm, 2],
    0xE5 => [:sbc, :zp,  3],
    0xF5 => [:sbc, :zpx, 4],
    0xED => [:sbc, :abs, 4],
    0xFD => [:sbc, :abx, 4],
    0xF9 => [:sbc, :aby, 4],
    0xE1 => [:sbc, :izx, 6],
    0xF1 => [:sbc, :izy, 5],

    # ===== Comparaisons =====
    # CMP
    0xC9 => [:cmp, :imm, 2],
    0xC5 => [:cmp, :zp,  3],
    0xD5 => [:cmp, :zpx, 4],
    0xCD => [:cmp, :abs, 4],
    0xDD => [:cmp, :abx, 4],
    0xD9 => [:cmp, :aby, 4],
    0xC1 => [:cmp, :izx, 6],
    0xD1 => [:cmp, :izy, 5],

    # CPX
    0xE0 => [:cpx, :imm, 2],
    0xE4 => [:cpx, :zp,  3],
    0xEC => [:cpx, :abs, 4],

    # CPY
    0xC0 => [:cpy, :imm, 2],
    0xC4 => [:cpy, :zp,  3],
    0xCC => [:cpy, :abs, 4],

    # ===== Incrémentation / Décrémentation =====
    0xE6 => [:inc, :zp,  5],
    0xF6 => [:inc, :zpx, 6],
    0xEE => [:inc, :abs, 6],
    0xFE => [:inc, :abx, 7],

    0xC6 => [:dec, :zp,  5],
    0xD6 => [:dec, :zpx, 6],
    0xCE => [:dec, :abs, 6],
    0xDE => [:dec, :abx, 7],

    0xE8 => [:inx, :imp, 2],
    0xC8 => [:iny, :imp, 2],
    0xCA => [:dex, :imp, 2],
    0x88 => [:dey, :imp, 2],

    # ===== Logique =====
    # AND
    0x29 => [:and_op, :imm, 2],
    0x25 => [:and_op, :zp,  3],
    0x35 => [:and_op, :zpx, 4],
    0x2D => [:and_op, :abs, 4],
    0x3D => [:and_op, :abx, 4],
    0x39 => [:and_op, :aby, 4],
    0x21 => [:and_op, :izx, 6],
    0x31 => [:and_op, :izy, 5],

    # ORA
    0x09 => [:ora, :imm, 2],
    0x05 => [:ora, :zp,  3],
    0x15 => [:ora, :zpx, 4],
    0x0D => [:ora, :abs, 4],
    0x1D => [:ora, :abx, 4],
    0x19 => [:ora, :aby, 4],
    0x01 => [:ora, :izx, 6],
    0x11 => [:ora, :izy, 5],

    # EOR
    0x49 => [:eor, :imm, 2],
    0x45 => [:eor, :zp,  3],
    0x55 => [:eor, :zpx, 4],
    0x4D => [:eor, :abs, 4],
    0x5D => [:eor, :abx, 4],
    0x59 => [:eor, :aby, 4],
    0x41 => [:eor, :izx, 6],
    0x51 => [:eor, :izy, 5],

    # BIT
    0x24 => [:bit, :zp,  3],
    0x2C => [:bit, :abs, 4],

    # ===== Décalages / Rotations =====
    # ASL
    0x0A => [:asl, :acc, 2],
    0x06 => [:asl, :zp,  5],
    0x16 => [:asl, :zpx, 6],
    0x0E => [:asl, :abs, 6],
    0x1E => [:asl, :abx, 7],

    # LSR
    0x4A => [:lsr, :acc, 2],
    0x46 => [:lsr, :zp,  5],
    0x56 => [:lsr, :zpx, 6],
    0x4E => [:lsr, :abs, 6],
    0x5E => [:lsr, :abx, 7],

    # ROL
    0x2A => [:rol, :acc, 2],
    0x26 => [:rol, :zp,  5],
    0x36 => [:rol, :zpx, 6],
    0x2E => [:rol, :abs, 6],
    0x3E => [:rol, :abx, 7],

    # ROR
    0x6A => [:ror, :acc, 2],
    0x66 => [:ror, :zp,  5],
    0x76 => [:ror, :zpx, 6],
    0x6E => [:ror, :abs, 6],
    0x7E => [:ror, :abx, 7],

    # ===== Branchements =====
    0x90 => [:bcc, :rel, 2],
    0xB0 => [:bcs, :rel, 2],
    0xF0 => [:beq, :rel, 2],
    0x30 => [:bmi, :rel, 2],
    0xD0 => [:bne, :rel, 2],
    0x10 => [:bpl, :rel, 2],
    0x50 => [:bvc, :rel, 2],
    0x70 => [:bvs, :rel, 2],

    # ===== Sauts / Sous-routines =====
    0x4C => [:jmp, :abs, 3],
    0x6C => [:jmp, :ind, 5],
    0x20 => [:jsr, :abs, 6],
    0x60 => [:rts, :imp, 6],

    # ===== Interruptions =====
    0x00 => [:brk, :imp, 7],
    0x40 => [:rti, :imp, 6],

    # ===== Flags =====
    0x18 => [:clc, :imp, 2],
    0xD8 => [:cld, :imp, 2],
    0x58 => [:cli, :imp, 2],
    0xB8 => [:clv, :imp, 2],
    0x38 => [:sec, :imp, 2],
    0xF8 => [:sed, :imp, 2],
    0x78 => [:sei, :imp, 2],

    # ===== NOP =====
    0xEA => [:nop, :imp, 2],

    # ===== Unofficial / Illegal opcodes (les plus courants) =====
    # NOP variants
    0x1A => [:nop, :imp, 2],
    0x3A => [:nop, :imp, 2],
    0x5A => [:nop, :imp, 2],
    0x7A => [:nop, :imp, 2],
    0xDA => [:nop, :imp, 2],
    0xFA => [:nop, :imp, 2],

    # DOP (Double NOP / SKB)
    0x04 => [:dop, :zp,  3],
    0x14 => [:dop, :zpx, 4],
    0x34 => [:dop, :zpx, 4],
    0x44 => [:dop, :zp,  3],
    0x54 => [:dop, :zpx, 4],
    0x64 => [:dop, :zp,  3],
    0x74 => [:dop, :zpx, 4],
    0x80 => [:dop, :imm, 2],
    0x82 => [:dop, :imm, 2],
    0x89 => [:dop, :imm, 2],
    0xC2 => [:dop, :imm, 2],
    0xD4 => [:dop, :zpx, 4],
    0xE2 => [:dop, :imm, 2],
    0xF4 => [:dop, :zpx, 4],

    # TOP (Triple NOP / SKW)
    0x0C => [:top, :abs, 4],
    0x1C => [:top, :abx, 4],
    0x3C => [:top, :abx, 4],
    0x5C => [:top, :abx, 4],
    0x7C => [:top, :abx, 4],
    0xDC => [:top, :abx, 4],
    0xFC => [:top, :abx, 4],

    # LAX (LDA + LDX)
    0xA3 => [:lax, :izx, 6],
    0xA7 => [:lax, :zp,  3],
    0xAF => [:lax, :abs, 4],
    0xB3 => [:lax, :izy, 5],
    0xB7 => [:lax, :zpy, 4],
    0xBF => [:lax, :aby, 4],

    # SAX (Store A & X)
    0x83 => [:sax, :izx, 6],
    0x87 => [:sax, :zp,  3],
    0x8F => [:sax, :abs, 4],
    0x97 => [:sax, :zpy, 4],

    # DCP (DEC + CMP)
    0xC3 => [:dcp, :izx, 8],
    0xC7 => [:dcp, :zp,  5],
    0xCF => [:dcp, :abs, 6],
    0xD3 => [:dcp, :izy, 8],
    0xD7 => [:dcp, :zpx, 6],
    0xDB => [:dcp, :aby, 7],
    0xDF => [:dcp, :abx, 7],

    # ISB / ISC (INC + SBC)
    0xE3 => [:isb, :izx, 8],
    0xE7 => [:isb, :zp,  5],
    0xEF => [:isb, :abs, 6],
    0xF3 => [:isb, :izy, 8],
    0xF7 => [:isb, :zpx, 6],
    0xFB => [:isb, :aby, 7],
    0xFF => [:isb, :abx, 7],

    # SLO (ASL + ORA)
    0x03 => [:slo, :izx, 8],
    0x07 => [:slo, :zp,  5],
    0x0F => [:slo, :abs, 6],
    0x13 => [:slo, :izy, 8],
    0x17 => [:slo, :zpx, 6],
    0x1B => [:slo, :aby, 7],
    0x1F => [:slo, :abx, 7],

    # RLA (ROL + AND)
    0x23 => [:rla, :izx, 8],
    0x27 => [:rla, :zp,  5],
    0x2F => [:rla, :abs, 6],
    0x33 => [:rla, :izy, 8],
    0x37 => [:rla, :zpx, 6],
    0x3B => [:rla, :aby, 7],
    0x3F => [:rla, :abx, 7],

    # SRE (LSR + EOR)
    0x43 => [:sre, :izx, 8],
    0x47 => [:sre, :zp,  5],
    0x4F => [:sre, :abs, 6],
    0x53 => [:sre, :izy, 8],
    0x57 => [:sre, :zpx, 6],
    0x5B => [:sre, :aby, 7],
    0x5F => [:sre, :abx, 7],

    # RRA (ROR + ADC)
    0x63 => [:rra, :izx, 8],
    0x67 => [:rra, :zp,  5],
    0x6F => [:rra, :abs, 6],
    0x73 => [:rra, :izy, 8],
    0x77 => [:rra, :zpx, 6],
    0x7B => [:rra, :aby, 7],
    0x7F => [:rra, :abx, 7],

    # SBC unofficial (identique à $E9)
    0xEB => [:sbc, :imm, 2],

  }.freeze
end