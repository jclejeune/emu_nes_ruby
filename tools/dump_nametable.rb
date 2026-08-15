# tools/dump_nametable.rb

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

# Laisser tourner 60 frames pour que le titre soit prêt
60.times do
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

puts "=== PPU State ==="
puts "PPUCTRL: $#{ppu.instance_variable_get(:@reg_control).to_s(16).upcase.rjust(2, '0')}"
puts "PPUMASK: $#{ppu.instance_variable_get(:@reg_mask).to_s(16).upcase.rjust(2, '0')}"
puts "PPUSTATUS: $#{ppu.instance_variable_get(:@reg_status).to_s(16).upcase.rjust(2, '0')}"
puts "Scroll v: $#{ppu.instance_variable_get(:@v).to_s(16).upcase.rjust(4, '0')}"
puts "Scroll t: $#{ppu.instance_variable_get(:@t).to_s(16).upcase.rjust(4, '0')}"
puts "Fine X: #{ppu.instance_variable_get(:@x)}"
puts

puts "=== Nametable 0 ($2000) — 32×30 tiles ==="
30.times do |row|
  32.times do |col|
    val = ppu_bus.read(0x2000 + row * 32 + col)
  end
  puts
end

puts
puts "=== Nametable 1 ($2400) — 32×30 tiles ==="
30.times do |row|
  32.times do |col|
    val = ppu_bus.read(0x2400 + row * 32 + col)
  end
  puts
end

puts
puts "=== Attribute table 0 ($23C0) — 8×8 ==="
8.times do |row|
  8.times do |col|
    val = ppu_bus.read(0x23C0 + row * 8 + col)
  end
  puts
end




oam = ppu.instance_variable_get(:@oam)
64.times do |i|
  y    = oam[i * 4]
  tile = oam[i * 4 + 1]
  attr = oam[i * 4 + 2]
  x    = oam[i * 4 + 3]
  next if y >= 240  # Sprite hidden

  puts format("  #%02d: Y=%3d Tile=$%02X Attr=$%02X X=%3d Pal=%d Flip=%s%s Behind=%s",
              i, y, tile, attr, x,
              attr & 0x03,
              (attr & 0x40) != 0 ? "H" : ".",
              (attr & 0x80) != 0 ? "V" : ".",
              (attr & 0x20) != 0 ? "yes" : "no")
end