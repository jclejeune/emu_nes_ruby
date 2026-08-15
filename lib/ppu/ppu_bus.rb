# lib/ppu/ppu_bus.rb

class PPUBus
  attr_reader :palette_ram

  def initialize
    @vram        = Array.new(0x0800, 0x00)
    @palette_ram = Array.new(32, 0x00)
    @cartridge   = nil
    @access_log  = []
  end

  def connect_cartridge(cartridge)
    @cartridge = cartridge
  end

  def read(address)
    address &= 0x3FFF

    case address
    when 0x0000..0x1FFF
      data = @cartridge&.ppu_read(address) || 0x00
      log(:read, address, data, "CHR")
      data

    when 0x2000..0x3EFF
      mirrored = mirror_nametable(address)
      data = @vram[mirrored]
      log(:read, address, data, "NT")
      data

    when 0x3F00..0x3FFF
      idx = mirror_palette(address)
      data = @palette_ram[idx]
      log(:read, address, data, "PAL(#{idx})")
      data

    else
      0x00
    end
  end

  def write(address, data)
    address &= 0x3FFF
    data    &= 0xFF

    case address
    when 0x0000..0x1FFF
      @cartridge&.ppu_write(address, data)
      log(:write, address, data, "CHR")

    when 0x2000..0x3EFF
      mirrored = mirror_nametable(address)
      @vram[mirrored] = data
      log(:write, address, data, "NT")

    when 0x3F00..0x3FFF
      idx = mirror_palette(address)
      @palette_ram[idx] = data
      log(:write, address, data, "PAL(#{idx})")
    end
  end

  def dump_last_accesses(count = 50)
    puts "\n=== Derniers #{count} acces PPU ==="
    @access_log.last(count).each do |entry|
      type = entry[:type] == :read ? "R" : "W"
      src  = entry[:source]
    end
  end

  private

  def log(type, addr, val, source)
    @access_log << { type: type, addr: addr, val: val, source: source }
    @access_log.shift if @access_log.length > 500
  end

  # Miroir palette : $3F10/$3F14/$3F18/$3F1C sont ALIAS de $3F00/$3F04/$3F08/$3F0C
  # (même cellule mémoire en lecture ET écriture)
  def mirror_palette(address)
    addr = address & 0x001F
    if addr == 0x10 || addr == 0x14 || addr == 0x18 || addr == 0x1C
      addr - 0x10
    else
      addr
    end
  end

  def mirror_nametable(address)
    addr = address & 0x0FFF
    mode = @cartridge&.mirror_mode || :horizontal

    if mode == :vertical
      # NT0 ($2000-$23FF) et NT2 ($2800-$2BFF) partagent VRAM 0
      # NT1 ($2400-$27FF) et NT3 ($2C00-$2FFF) partagent VRAM 1
      addr & 0x07FF
    else
      # Horizontal :
      # NT0 ($2000-$23FF) et NT1 ($2400-$27FF) partagent VRAM 0
      # NT2 ($2800-$2BFF) et NT3 ($2C00-$2FFF) partagent VRAM 1
      if addr < 0x0800
        addr & 0x03FF
      else
        0x0400 + (addr & 0x03FF)
      end
    end
  end
end