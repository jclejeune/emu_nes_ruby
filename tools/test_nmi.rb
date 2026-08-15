# tools/test_nmi.rb

$LOAD_PATH.unshift(File.join(__dir__, "..", "lib"))
require "bus/bus"
require "cpu/cpu"
require "ppu/ppu"
require "cartridge/cartridge"
require "input/joypad"

rom = ARGV[0] || "roms/super_mario_bros.nes"

ppu = PPU.new
bus = Bus.new(ppu, nil, Joypad.new, Joypad.new)
cpu = CPU.new(bus)

cartridge = Cartridge.load(rom)
bus.insert_cartridge(cartridge)
ppu.connect_cartridge(cartridge)

cpu.reset
ppu.reset

nmi_count = 0
last_nmi_pc = 0

# Compter les NMIs
bus.define_singleton_method(:read) do |address|
  if (0x2000..0x3FFF).include?(address)
    ppu.cpu_read(address & 0x0007)
  else
    super(address)
  end
end

# Tracer les NMIs
original_nmi = cpu.method(:nmi)
cpu.define_singleton_method(:nmi) do
  nmi_count += 1
  $stderr.puts "NMI ##{nmi_count} at CYC=#{instance_variable_get(:@total_cycles)}" if nmi_count <= 5
  original_nmi.call
end

3.times do |frame|
  loop do
    cycles = cpu.step
    (cycles * 3).times do
      ppu.step
      if ppu.nmi_triggered?
        cpu.nmi
        ppu.clear_nmi
      end
    end
    break if ppu.frame_complete
  end
  ppu.consume_frame!
  puts "Frame #{frame + 1}: #{nmi_count} NMIs total"
end

puts
puts "Total NMIs: #{nmi_count} (attendu: ~3-4 par frame x 3 frames = 9-12)"