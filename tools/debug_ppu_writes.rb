# tools/debug_ppu_writes.rb

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

puts "Execution jusqu a la frame 30..."
30.times do |frame|
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
  puts "Frame #{frame + 1} OK. PC: $#{cpu.pc.to_s(16).upcase}"
end

ppu_bus = ppu.instance_variable_get(:@bus)

puts "\n=== ETAT FINAL PALETTE ===\n"
print "BG: "
16.times { |i| print "#{ppu_bus.read(0x3F00 + i).to_s(16).upcase.rjust(2,'0')} " }
puts
print "SP: "
16.times { |i| print "#{ppu_bus.read(0x3F10 + i).to_s(16).upcase.rjust(2,'0')} " }
puts

puts "\n=== Derniers 100 acces PPU (enfin ceux interessants) ===\n"

# Filtrer pour voir seulement les acces palette et NT 2000-23FF
ppu_bus.dump_last_accesses(200)