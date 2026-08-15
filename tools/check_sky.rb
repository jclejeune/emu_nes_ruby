# tools/check_sky.rb

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

# Attendre 60 frames pour que tout soit charge
60.times do |frame|
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
end

ppu_bus = ppu.instance_variable_get(:@bus)

puts "=== CRITIQUE : Couleur du ciel ===\n"


c = NESPalette.rgb(ppu_bus.read(0x3F00)) rescue ["?","?","?"]
puts "RGB(#{c.join(',')}) - #{c == [84,84,84] ? 'NOIR (bug!)' : 'OK'}"

puts "\nToutes les couleurs 0 de chaque palette BG:"
4.times do |i|
  val = ppu_bus.read(0x3F00 + i * 4)
end

puts "\n=== Tiles qui composent le CIEL (ligne scanline 10-50) ===\n"
# Lire la nametable ligne 5-15 (haut ecran = ciel)
(5..20).each do |row|
  line = ""
  32.times do |col|
    tile_id = ppu_bus.read(0x2000 + row * 32 + col)
    line += tile_id.to_s(16).upcase.rjust(2,'0') + " "
  end
  puts "#{row.to_s.rjust(2)}: #{line}"
end

puts "\n>>> Si tu vois des '00' partout dans ces lignes, le ciel est fait de tiles 0x00"
puts ">>> Ces tiles ont tous leurs pixels transparents (valent 0)"
 puts ">>> Donc ils prennent la couleur $3F00 (universelle)"

puts "\n=== OAM complet (tous les sprites) ===\n"
oam = ppu.instance_variable_get(:@oam)
64.times do |i|
  y = oam[i*4]; t = oam[i*4+1]; a = oam[i*4+2]; x = oam[i*4+3]
  next if y >= 240  # Sprite caché
  
  palette = 4 + (a & 0x03)
  behind  = (a & 0x20) != 0
  flip_h  = (a & 0x40) != 0
  flip_v  = (a & 0x80) != 0
  
end

if (0...256).all? { |i| oam[i] == 0 }
  puts "\n⚠️ WARNING : OAM ENTIEREMENT A ZERO !!!!!"
  puts "   Les sprites ne sont PAS charges !"
end