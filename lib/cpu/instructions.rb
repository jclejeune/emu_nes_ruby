# lib/cpu/instructions.rb

module Instructions
  # ===== Helpers =====

  def set_zn(value)
    set_flag(:Z, (value & 0xFF) == 0)
    set_flag(:N, (value & 0x80) != 0)
  end

  def push(value)
    write(0x0100 | @sp, value & 0xFF)
    @sp = (@sp - 1) & 0xFF
  end

  def pull
    @sp = (@sp + 1) & 0xFF
    read(0x0100 | @sp)
  end

  def push16(value)
    push((value >> 8) & 0xFF)
    push(value & 0xFF)
  end

  def pull16
    lo = pull
    hi = pull
    (hi << 8) | lo
  end

  def branch(addr, page_crossed)
    @cycles += 1  # Branchement pris = +1 cycle
    @cycles += 1 if page_crossed  # Page crossing = +1 cycle supplémentaire
    @pc = addr
  end

  # ===== Chargement =====

  def lda(addr, _page_crossed)
    @a = read(addr)
    set_zn(@a)
  end

  def ldx(addr, _page_crossed)
    @x = read(addr)
    set_zn(@x)
  end

  def ldy(addr, _page_crossed)
    @y = read(addr)
    set_zn(@y)
  end

  # ===== Stockage =====

  def sta(addr, _page_crossed)
    write(addr, @a)
  end

  def stx(addr, _page_crossed)
    write(addr, @x)
  end

  def sty(addr, _page_crossed)
    write(addr, @y)
  end

  # ===== Transferts =====

  def tax(_addr, _page_crossed)
    @x = @a
    set_zn(@x)
  end

  def tay(_addr, _page_crossed)
    @y = @a
    set_zn(@y)
  end

  def txa(_addr, _page_crossed)
    @a = @x
    set_zn(@a)
  end

  def tya(_addr, _page_crossed)
    @a = @y
    set_zn(@a)
  end

  def tsx(_addr, _page_crossed)
    @x = @sp
    set_zn(@x)
  end

  def txs(_addr, _page_crossed)
    @sp = @x
  end

  # ===== Stack =====

  def pha(_addr, _page_crossed)
    push(@a)
  end

  def pla(_addr, _page_crossed)
    @a = pull
    set_zn(@a)
  end

  def php(_addr, _page_crossed)
    # Push avec flags B et U forcés à 1
    push(@status | 0x30)
  end

  def plp(_addr, _page_crossed)
    @status = pull
    set_flag(:U, true)   # Toujours à 1
    set_flag(:B, false)  # Toujours à 0 après PLP
  end

  # ===== Arithmétique =====

  def adc(addr, _page_crossed)
    value = read(addr)
    # Pas de mode BCD sur le 2A03 !
    temp = @a + value + (flag?(:C) ? 1 : 0)
    set_flag(:C, temp > 0xFF)
    set_flag(:V, (~(@a ^ value) & (@a ^ temp) & 0x80) != 0)
    @a = temp & 0xFF
    set_zn(@a)
  end

  def sbc(addr, _page_crossed)
    value = read(addr)
    # SBC = ADC avec complément à 1
    value_inv = value ^ 0xFF
    temp = @a + value_inv + (flag?(:C) ? 1 : 0)
    set_flag(:C, temp > 0xFF)
    set_flag(:V, (~(@a ^ value_inv) & (@a ^ temp) & 0x80) != 0)
    @a = temp & 0xFF
    set_zn(@a)
  end

  # ===== Comparaisons =====

  def compare(register, addr)
    value = read(addr)
    result = register - value
    set_flag(:C, register >= value)
    set_zn(result)
  end

  def cmp(addr, _page_crossed)
    compare(@a, addr)
  end

  def cpx(addr, _page_crossed)
    compare(@x, addr)
  end

  def cpy(addr, _page_crossed)
    compare(@y, addr)
  end

  # ===== Incrémentation / Décrémentation =====

  def inc(addr, _page_crossed)
    value = (read(addr) + 1) & 0xFF
    write(addr, value)
    set_zn(value)
  end

  def dec(addr, _page_crossed)
    value = (read(addr) - 1) & 0xFF
    write(addr, value)
    set_zn(value)
  end

  def inx(_addr, _page_crossed)
    @x = (@x + 1) & 0xFF
    set_zn(@x)
  end

  def iny(_addr, _page_crossed)
    @y = (@y + 1) & 0xFF
    set_zn(@y)
  end

  def dex(_addr, _page_crossed)
    @x = (@x - 1) & 0xFF
    set_zn(@x)
  end

  def dey(_addr, _page_crossed)
    @y = (@y - 1) & 0xFF
    set_zn(@y)
  end

  # ===== Logique =====

  def and_op(addr, _page_crossed)
    @a &= read(addr)
    set_zn(@a)
  end

  def ora(addr, _page_crossed)
    @a |= read(addr)
    set_zn(@a)
  end

  def eor(addr, _page_crossed)
    @a ^= read(addr)
    set_zn(@a)
  end

  def bit(addr, _page_crossed)
    value = read(addr)
    set_flag(:Z, (@a & value) == 0)
    set_flag(:V, (value & 0x40) != 0)
    set_flag(:N, (value & 0x80) != 0)
  end

  # ===== Décalages / Rotations =====

  def asl(addr, _page_crossed)
    if addr.nil? # Accumulator
      set_flag(:C, (@a & 0x80) != 0)
      @a = (@a << 1) & 0xFF
      set_zn(@a)
    else
      value = read(addr)
      set_flag(:C, (value & 0x80) != 0)
      value = (value << 1) & 0xFF
      write(addr, value)
      set_zn(value)
    end
  end

  def lsr(addr, _page_crossed)
    if addr.nil?
      set_flag(:C, (@a & 0x01) != 0)
      @a >>= 1
      set_zn(@a)
    else
      value = read(addr)
      set_flag(:C, (value & 0x01) != 0)
      value >>= 1
      write(addr, value)
      set_zn(value)
    end
  end

  def rol(addr, _page_crossed)
    carry_in = flag?(:C) ? 1 : 0
    if addr.nil?
      set_flag(:C, (@a & 0x80) != 0)
      @a = ((@a << 1) | carry_in) & 0xFF
      set_zn(@a)
    else
      value = read(addr)
      set_flag(:C, (value & 0x80) != 0)
      value = ((value << 1) | carry_in) & 0xFF
      write(addr, value)
      set_zn(value)
    end
  end

  def ror(addr, _page_crossed)
    carry_in = flag?(:C) ? 0x80 : 0
    if addr.nil?
      set_flag(:C, (@a & 0x01) != 0)
      @a = (@a >> 1) | carry_in
      set_zn(@a)
    else
      value = read(addr)
      set_flag(:C, (value & 0x01) != 0)
      value = (value >> 1) | carry_in
      write(addr, value)
      set_zn(value)
    end
  end

  # ===== Branchements =====

  def bcc(addr, page_crossed)
    branch(addr, page_crossed) unless flag?(:C)
  end

  def bcs(addr, page_crossed)
    branch(addr, page_crossed) if flag?(:C)
  end

  def beq(addr, page_crossed)
    branch(addr, page_crossed) if flag?(:Z)
  end

  def bne(addr, page_crossed)
    branch(addr, page_crossed) unless flag?(:Z)
  end

  def bmi(addr, page_crossed)
    branch(addr, page_crossed) if flag?(:N)
  end

  def bpl(addr, page_crossed)
    branch(addr, page_crossed) unless flag?(:N)
  end

  def bvc(addr, page_crossed)
    branch(addr, page_crossed) unless flag?(:V)
  end

  def bvs(addr, page_crossed)
    branch(addr, page_crossed) if flag?(:V)
  end

  # ===== Sauts =====

  def jmp(addr, _page_crossed)
    @pc = addr
  end

  def jsr(addr, _page_crossed)
    push16((@pc - 1) & 0xFFFF)
    @pc = addr
  end

  def rts(_addr, _page_crossed)
    @pc = (pull16 + 1) & 0xFFFF
  end

  # ===== Interruptions =====

  def brk(_addr, _page_crossed)
    @pc = (@pc + 1) & 0xFFFF  # BRK pousse PC+2 (skip padding byte)
    push16(@pc)
    push(@status | 0x30)  # B et U forcés à 1
    set_flag(:I, true)
    @pc = read16(0xFFFE)
  end

  def rti(_addr, _page_crossed)
    @status = pull
    set_flag(:U, true)
    set_flag(:B, false)
    @pc = pull16
  end

  # ===== Flags =====

  def clc(_addr, _page_crossed)
    set_flag(:C, false)
  end

  def cld(_addr, _page_crossed)
    set_flag(:D, false)
  end

  def cli(_addr, _page_crossed)
    set_flag(:I, false)
  end

  def clv(_addr, _page_crossed)
    set_flag(:V, false)
  end

  def sec(_addr, _page_crossed)
    set_flag(:C, true)
  end

  def sed(_addr, _page_crossed)
    set_flag(:D, true)
  end

  def sei(_addr, _page_crossed)
    set_flag(:I, true)
  end

  # ===== NOP =====

  def nop(_addr, _page_crossed)
    # Rien
  end

  # DOP = Double NOP (lit un byte et l'ignore)
  def dop(addr, _page_crossed)
    read(addr) if addr
  end

  # TOP = Triple NOP (lit deux bytes et les ignore)
  def top(addr, _page_crossed)
    read(addr) if addr
  end

  # ===== Illegal Opcodes =====

  def lax(addr, _page_crossed)
    @a = read(addr)
    @x = @a
    set_zn(@a)
  end

  def sax(addr, _page_crossed)
    write(addr, @a & @x)
  end

  def dcp(addr, _page_crossed)
    # DEC + CMP
    value = (read(addr) - 1) & 0xFF
    write(addr, value)
    result = @a - value
    set_flag(:C, @a >= value)
    set_zn(result)
  end

  def isb(addr, _page_crossed)
    # INC + SBC
    value = (read(addr) + 1) & 0xFF
    write(addr, value)
    # SBC inline
    value_inv = value ^ 0xFF
    temp = @a + value_inv + (flag?(:C) ? 1 : 0)
    set_flag(:C, temp > 0xFF)
    set_flag(:V, (~(@a ^ value_inv) & (@a ^ temp) & 0x80) != 0)
    @a = temp & 0xFF
    set_zn(@a)
  end

  def slo(addr, _page_crossed)
    # ASL + ORA
    value = read(addr)
    set_flag(:C, (value & 0x80) != 0)
    value = (value << 1) & 0xFF
    write(addr, value)
    @a |= value
    set_zn(@a)
  end

  def rla(addr, _page_crossed)
    # ROL + AND
    carry_in = flag?(:C) ? 1 : 0
    value = read(addr)
    set_flag(:C, (value & 0x80) != 0)
    value = ((value << 1) | carry_in) & 0xFF
    write(addr, value)
    @a &= value
    set_zn(@a)
  end

  def sre(addr, _page_crossed)
    # LSR + EOR
    value = read(addr)
    set_flag(:C, (value & 0x01) != 0)
    value >>= 1
    write(addr, value)
    @a ^= value
    set_zn(@a)
  end

  def rra(addr, _page_crossed)
    # ROR + ADC
    carry_in = flag?(:C) ? 0x80 : 0
    value = read(addr)
    set_flag(:C, (value & 0x01) != 0)
    value = (value >> 1) | carry_in
    write(addr, value)
    # ADC inline
    temp = @a + value + (flag?(:C) ? 1 : 0)
    set_flag(:C, temp > 0xFF)
    set_flag(:V, (~(@a ^ value) & (@a ^ temp) & 0x80) != 0)
    @a = temp & 0xFF
    set_zn(@a)
  end
end