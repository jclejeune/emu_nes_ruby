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
      @ppu ? @ppu.cpu_read(address & 7) : 0x00
    when 0x4016
      @joypad1 ? @joypad1.read : 0x00
    when 0x4017
      @joypad2 ? @joypad2.read : 0x00
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
      @ppu&.cpu_write(address & 7, data)
    when 0x4014
      if @ppu
        page = data << 8
        256.times { |i| @ppu.write_oam(i, read(page + i)) }
      end
    when 0x4016
      @joypad1&.write(data)
      @joypad2&.write(data)
    when 0x4020..0xFFFF
      @cartridge&.cpu_write(address, data)
    end
  end

  def debug_read(address)
    address &= 0xFFFF
    case address
    when 0x0000..0x1FFF then @ram[address & 0x07FF]
    when 0x8000..0xFFFF then @cartridge ? @cartridge.cpu_read(address) : 0x00
    else 0x00
    end
  end
end