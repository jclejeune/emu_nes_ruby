# lib/cartridge/mappers/mapper_004.rb

require_relative "mapper"

class Mapper004 < Mapper
  attr_reader :irq_pending

  def initialize(prg_banks, chr_banks)
    super
    @prg_bank_count = [prg_banks * 2, 2].max
    @chr_bank_count = [chr_banks * 8, 8].max

    @bank_data   = Array.new(8, 0)
    @reg_target  = 0
    @prg_mode    = 0
    @chr_mode    = 0
    @mirroring   = :horizontal
    @prg_ram_ok  = true
    @last_data   = 0

    @irq_latch   = 0
    @irq_counter = 0
    @irq_reload  = false
    @irq_enabled = false
    @irq_pending = false

    @prg_offsets = Array.new(4, 0)
    @chr_offsets = Array.new(8, 0)
    apply_banks
  end

  def mirror_mode
    @mirroring
  end

  def capture_write(data)
    @last_data = data & 0xFF
  end

  def map_cpu_read(address)
    return nil unless address >= 0x6000

    if address < 0x8000
      return nil unless @prg_ram_ok
      address - 0x6000
    else
      bank = (address - 0x8000) / 0x2000
      @prg_offsets[bank] + (address & 0x1FFF)
    end
  end

  def map_cpu_write(address)
    if address >= 0x6000 && address < 0x8000
      return nil unless @prg_ram_ok
      return address - 0x6000
    end

    return nil unless address >= 0x8000

    even = (address & 1) == 0

    case address
    when 0x8000..0x9FFF
      if even
        @reg_target = @last_data & 0x07
        @prg_mode   = (@last_data >> 6) & 1
        @chr_mode   = (@last_data >> 7) & 1
      else
        @bank_data[@reg_target] = @last_data
        apply_banks
      end
    when 0xA000..0xBFFF
      if even
        @mirroring = (@last_data & 1) == 0 ? :vertical : :horizontal
      else
        @prg_ram_ok = (@last_data & 0x80) != 0
      end
    when 0xC000..0xDFFF
      if even
        @irq_latch = @last_data
      else
        @irq_reload = true
      end
    when 0xE000..0xFFFF
      if even
        @irq_enabled = false
        @irq_pending = false
      else
        @irq_enabled = true
      end
    end

    nil
  end

  def map_ppu_read(address)
    return nil unless address <= 0x1FFF
    bank = address / 0x0400
    @chr_offsets[bank] + (address & 0x03FF)
  end

  def map_ppu_write(address)
    return nil unless address <= 0x1FFF
    return nil if @chr_banks > 0
    bank = address / 0x0400
    @chr_offsets[bank] + (address & 0x03FF)
  end

  def clock_scanline
    if @irq_counter == 0 || @irq_reload
      @irq_counter = @irq_latch
      @irq_reload = false
    else
      @irq_counter -= 1
    end

    @irq_pending = true if @irq_counter == 0 && @irq_enabled
  end

  def clear_irq
    @irq_pending = false
  end

  private

  def apply_banks
    last  = @prg_bank_count - 1
    last2 = @prg_bank_count - 2
    r6 = @bank_data[6] % @prg_bank_count
    r7 = @bank_data[7] % @prg_bank_count

    if @prg_mode == 0
      @prg_offsets[0] = r6 * 0x2000
      @prg_offsets[1] = r7 * 0x2000
      @prg_offsets[2] = last2 * 0x2000
      @prg_offsets[3] = last * 0x2000
    else
      @prg_offsets[0] = last2 * 0x2000
      @prg_offsets[1] = r7 * 0x2000
      @prg_offsets[2] = r6 * 0x2000
      @prg_offsets[3] = last * 0x2000
    end

    r = @bank_data.map { |b| b % @chr_bank_count }

    if @chr_mode == 0
      @chr_offsets[0] = (r[0] & 0xFE) * 0x0400
      @chr_offsets[1] = (r[0] | 0x01) * 0x0400
      @chr_offsets[2] = (r[1] & 0xFE) * 0x0400
      @chr_offsets[3] = (r[1] | 0x01) * 0x0400
      @chr_offsets[4] = r[2] * 0x0400
      @chr_offsets[5] = r[3] * 0x0400
      @chr_offsets[6] = r[4] * 0x0400
      @chr_offsets[7] = r[5] * 0x0400
    else
      @chr_offsets[0] = r[2] * 0x0400
      @chr_offsets[1] = r[3] * 0x0400
      @chr_offsets[2] = r[4] * 0x0400
      @chr_offsets[3] = r[5] * 0x0400
      @chr_offsets[4] = (r[0] & 0xFE) * 0x0400
      @chr_offsets[5] = (r[0] | 0x01) * 0x0400
      @chr_offsets[6] = (r[1] & 0xFE) * 0x0400
      @chr_offsets[7] = (r[1] | 0x01) * 0x0400
    end
  end
end