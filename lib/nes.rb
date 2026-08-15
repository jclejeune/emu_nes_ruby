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
  frame_count = 0
  start_time = Time.now

  while @running
    step_frame

    @screen.render(@ppu.frame_buffer)
    @ppu.consume_frame!
    @running = @screen.poll_events(@joypad1, @joypad2)

    frame_count += 1

    if (frame_count % 60) == 0
      elapsed = Time.now - start_time
      fps = frame_count / elapsed
      print "\rFPS: #{fps.round(1)}  "
    end

  end

  @screen.cleanup
  puts "\nArrêt après #{frame_count} frames."
end

  private

  def step_frame
  nmi_pending = false
  loop do
    cpu_cycles = @cpu.step

    (cpu_cycles * 3).times do
      ppu_nmi_before = @ppu.nmi_triggered?
      @ppu.step
      
      # Front montant : nmi était false, maintenant true
      if !ppu_nmi_before && @ppu.nmi_triggered?
        nmi_pending = true
      end
      
      if nmi_pending
        @cpu.nmi
        @ppu.clear_nmi
        nmi_pending = false
      end
    end

    break if @ppu.frame_complete
  end
end

end