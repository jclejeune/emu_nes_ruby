# tools/test_palette.rb

$LOAD_PATH.unshift(File.join(__dir__, "..", "lib"))

require "bus/bus"
require "cpu/cpu"
require "ppu/ppu"
require "cartridge/cartridge"
require "input/joypad"

rom = ARGV[0] || "roms/super_mario_bros.nes"

ppu     = PPU.new
joypad1 = Joypad.new
joypad2 = Joypad.new
bus     = Bus.new(ppu, nil, joypad1, joypad2)
cpu     = CPU.new(bus)

cartridge = Cartridge.load(rom)
bus.insert_cartridge(cartridge)
ppu.connect_cartridge(cartridge)

cpu.reset
ppu.reset

puts "Execution jusqu a la frame 10..."
10.times do |frame|
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
  puts "Frame #{frame + 1} terminee. PC: $#{cpu.pc.to_s(16).upcase}"
end

ppu_bus = ppu.instance_variable_get(:@bus)

puts "\n=== RESULTAT CRITIQUE ===\n\n"

ppu_bus.dump_palette_log


puts "\n=== Test direct des addresses ==="
[0x3F00, 0x3F01, 0x3F02, 0x3F03,
 0x3F04, 0x3F05, 0x3F06, 0x3F07,
 0x3F08, 0x3F09, 0x3F0A, 0x3F0B,
 0x3F0C, 0x3F0D, 0x3F0E, 0x3F0F].each do |addr|
  val = ppu_bus.read(addr)
end