# lib/bus/bus.rb

class Bus
  def initialize(ppu = nil, apu = nil, joypad1 = nil, joypad2 = nil)
    @ram       = Array.new(0x0800, 0x00)
    @ppu       = ppu
    @apu       = apu
    @joypad1   = joypad1
    @joypad2   = joypad2
    @cartridge = nil
  end

  def insert_cartridge(cartridge)
    @cartridge = cartridge
  end

  def read(address)
    address &= 0xFFFF

    case address
    when 0x0000..0x1FFF
      @ram[address & 0x07FF]

    when 0x2000..0x3FFF
      # PPU registers : 8 registres mirrorés tous les 8 bytes
      if @ppu
        @ppu.cpu_read(address & 0x2007)
      else
        0x00
      end

    when 0x4000..0x4013
      0x00

    when 0x4014
      0x00

    when 0x4015
      0x00

    when 0x4016
      @joypad1 ? @joypad1.read : 0x00

    when 0x4017
      @joypad2 ? @joypad2.read : 0x00

    when 0x4018..0x401F
      0x00

    when 0x4020..0xFFFF
      @cartridge ? @cartridge.cpu_read(address) : 0x00

    else
      0x00
    end
  end

  def write(address, data)
    address &= 0xFFFF
    data    &= 0xFF

    case address
    when 0x0000..0x1FFF
      @ram[address & 0x07FF] = data

    when 0x2000..0x3FFF
      # PPU registers
      if @ppu
        @ppu.cpu_write(address & 0x2007, data)
      end

    when 0x4000..0x4013
      # APU (TODO)

    when 0x4014
      # OAM DMA
      if @ppu
        base = data << 8
        256.times do |i|
          byte = read(base + i)
          @ppu.write_oam(i, byte)
        end
      end

    when 0x4015
      # APU status (TODO)

    when 0x4016
      @joypad1&.write(data)
      @joypad2&.write(data)

    when 0x4017
      # APU frame counter (TODO)

    when 0x4020..0xFFFF
      @cartridge&.cpu_write(address, data)
    end
  end

  # Lecture sans effets de bord (pour debug/logging)
  def debug_read(address)
    address &= 0xFFFF

    case address
    when 0x0000..0x1FFF
      @ram[address & 0x07FF]
    when 0x4020..0xFFFF
      @cartridge ? @cartridge.cpu_read(address) : 0x00
    else
      0x00
    end
  end
end