# lib/nes.rb

require_relative "bus/bus"
require_relative "cpu/cpu"
require_relative "ppu/ppu"
require_relative "cartridge/cartridge"
require_relative "input/joypad"
require_relative "display/screen"

class NES
  def initialize
    @joypad1   = Joypad.new
    @joypad2   = Joypad.new
    @ppu       = PPU.new
    @bus       = Bus.new(@ppu, nil, @joypad1, @joypad2)
    @cpu       = CPU.new(@bus)
    @screen    = Screen.new
    @running   = false
  end

  def load_rom(path)
    @cartridge = Cartridge.load(path)
    @bus.insert_cartridge(@cartridge)
    @ppu.connect_cartridge(@cartridge)
    puts "ROM: #{@cartridge.info}"
  end

  def power_on
    @cpu.reset
    @ppu.reset
    puts "CPU PC: $#{@cpu.pc.to_s(16).upcase.rjust(4, '0')}"
  end

def run
  @running = true
  while @running
    step_frame
    @screen.render(@ppu.frame_buffer)
    @ppu.consume_frame!
    @running = @screen.poll_events(@joypad1, @joypad2)
  end
  @screen.cleanup
end

def step_frame
  loop do
    cpu_cycles = @cpu.step
    (cpu_cycles * 3).times do
      @ppu.step
      if @ppu.nmi_triggered?
        @cpu.nmi
        @ppu.clear_nmi
      end
    end
    break if @ppu.frame_complete
  end
end

end