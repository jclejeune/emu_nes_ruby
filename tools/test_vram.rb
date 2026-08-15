# tools/test_vram.rb

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

puts "=== Test VRAM addressing ===\n\n"

# Simuler manuellement ce que SMB fait :
# 1. Set PPUADDR to $3F00 (palette)
# 2. Write palette bytes

puts "--- Simulation manuelle ---"
ppu.cpu_write(0x06, 0x3F)  # high byte
ppu.cpu_write(0x06, 0x00)  # low byte
printf "Apres set $3F00: v should be $3F00, actual = $%04X\n\n", ppu.instance_variable_get(:@v)

ppu.cpu_write(0x07, 0x22)  # Should go to $3F00!
ppu.cpu_write(0x07, 0x29)  # Should go to $3F01!
ppu.cpu_write(0x07, 0x1A)  # Should go to $3F02!

puts "\n--- Palette apres ecriture directe ---"
print "BG: "
16.times { |i| print "#{bus.debug_read_ppu? || bus.read(0x3F00 + i)}" } rescue puts "(no debug)"
puts "\n\n"

puts "=== Execution reelle du jeu (frames 1-3) ===\n"
cpu.reset
ppu.reset

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
  puts "\n--- Frame #{frame+1} terminee ---\n"
end

puts "\n--- Etat final palette ---"
print "BG: "
16.times { |i| print "$#{bus.read(0x3F00 + i).to_s(16).upcase.rjust(2,'0')} " }
puts
puts