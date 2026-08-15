# lib/cpu/interrupts.rb

module Interrupts
  # Vecteurs d'interruption
  NMI_VECTOR   = 0xFFFA
  RESET_VECTOR = 0xFFFC
  IRQ_VECTOR   = 0xFFFE

  def read16(address)
    lo = read(address)
    hi = read((address + 1) & 0xFFFF)
    (hi << 8) | lo
  end

  def reset
    @a = 0x00
    @x = 0x00
    @y = 0x00
    @sp = 0xFD
    @status = 0x00 | 0x04 | 0x20  # I=1, U=1
    @pc = read16(RESET_VECTOR)
    @cycles = 8
  end

  def nmi
    push16(@pc)
    set_flag(:B, false)
    set_flag(:U, true)
    set_flag(:I, true)
    push(@status)
    @pc = read16(NMI_VECTOR)
    @cycles += 7
    end

  def irq
    return if flag?(:I)

    push16(@pc)
    set_flag(:B, false)
    set_flag(:U, true)
    set_flag(:I, true)
    push(@status)
    @pc = read16(IRQ_VECTOR)
    @cycles += 7
  end
end