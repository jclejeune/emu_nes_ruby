# lib/cpu/addressing_modes.rb

module AddressingModes
  # Retourne [adresse, page_crossed]
  # Pour :accumulator et :implicit, retourne [nil, false]
  # Pour :immediate, retourne [pc, false] puis pc += 1

  def addr_implicit
    [nil, false]
  end

  def addr_accumulator
    [nil, false]
  end

  def addr_immediate
    addr = @pc
    @pc = (@pc + 1) & 0xFFFF
    [addr, false]
  end

  def addr_zero_page
    addr = read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    [addr, false]
  end

  def addr_zero_page_x
    base = read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    [(base + @x) & 0xFF, false]
  end

  def addr_zero_page_y
    base = read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    [(base + @y) & 0xFF, false]
  end

  def addr_absolute
    lo = read(@pc)
    hi = read((@pc + 1) & 0xFFFF)
    @pc = (@pc + 2) & 0xFFFF
    [(hi << 8) | lo, false]
  end

  def addr_absolute_x
    lo = read(@pc)
    hi = read((@pc + 1) & 0xFFFF)
    @pc = (@pc + 2) & 0xFFFF
    base = (hi << 8) | lo
    addr = (base + @x) & 0xFFFF
    page_crossed = (base & 0xFF00) != (addr & 0xFF00)
    [addr, page_crossed]
  end

  def addr_absolute_y
    lo = read(@pc)
    hi = read((@pc + 1) & 0xFFFF)
    @pc = (@pc + 2) & 0xFFFF
    base = (hi << 8) | lo
    addr = (base + @y) & 0xFFFF
    page_crossed = (base & 0xFF00) != (addr & 0xFF00)
    [addr, page_crossed]
  end

  def addr_indirect
    lo = read(@pc)
    hi = read((@pc + 1) & 0xFFFF)
    @pc = (@pc + 2) & 0xFFFF
    ptr = (hi << 8) | lo

    # Bug hardware 6502 : page boundary wrapping
    if (ptr & 0x00FF) == 0x00FF
      addr_lo = read(ptr)
      addr_hi = read(ptr & 0xFF00)
    else
      addr_lo = read(ptr)
      addr_hi = read((ptr + 1) & 0xFFFF)
    end

    [(addr_hi << 8) | addr_lo, false]
  end

  def addr_indexed_indirect # (d, X)
    base = read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    ptr = (base + @x) & 0xFF
    lo = read(ptr)
    hi = read((ptr + 1) & 0xFF)
    [(hi << 8) | lo, false]
  end

  def addr_indirect_indexed # (d), Y
    ptr = read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    lo = read(ptr)
    hi = read((ptr + 1) & 0xFF)
    base = (hi << 8) | lo
    addr = (base + @y) & 0xFFFF
    page_crossed = (base & 0xFF00) != (addr & 0xFF00)
    [addr, page_crossed]
  end

  def addr_relative
    offset = read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    offset -= 256 if offset > 127
    addr = (@pc + offset) & 0xFFFF
    page_crossed = (@pc & 0xFF00) != (addr & 0xFF00)
    [addr, page_crossed]
  end
end