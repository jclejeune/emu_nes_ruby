# lib/cartridge/mappers/mapper_000.rb

require_relative "mapper"

class Mapper000 < Mapper
  # NROM
  # CPU $8000-$BFFF : Premier bank 16KB PRG-ROM
  # CPU $C000-$FFFF : Dernier bank (ou miroir si 1 seul bank)
  # PPU $0000-$1FFF : 8KB CHR-ROM

  def initialize(prg_banks, chr_banks)
    super
    @prg_mask = prg_banks > 1 ? 0x7FFF : 0x3FFF
  end

  def map_cpu_read(address)
    return nil unless address >= 0x8000

    address & @prg_mask
  end

  def map_cpu_write(address)
    return nil unless address >= 0x8000

    address & @prg_mask
  end

  def map_ppu_read(address)
    return nil unless address <= 0x1FFF

    address
  end

  def map_ppu_write(address)
    return nil unless address <= 0x1FFF
    # CHR-RAM seulement (si chr_banks == 0)
    return nil if @chr_banks > 0

    address
  end
end