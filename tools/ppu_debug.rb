# tools/ppu_debug.rb

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

puts "=== Diagnostic PPU ==="
puts "ROM: #{cartridge.info}"
puts "CPU PC: $#{cpu.pc.to_s(16).upcase.rjust(4, '0')}"
puts

# Exécuter quelques frames pour laisser le jeu s'initialiser
frames = 0
total_cpu_cycles = 0

5.times do
  loop do
    cpu_cycles = cpu.step
    total_cpu_cycles += cpu_cycles

    (cpu_cycles * 3).times do
      ppu.step
      if ppu.nmi_triggered?
        cpu.nmi
        ppu.clear_nmi
      end
    end

    if ppu.frame_complete
      frames += 1
      break
    end
  end
end

puts "Frames exécutées: #{frames}"
puts "Cycles CPU totaux: #{total_cpu_cycles}"
puts

# === Diagnostic des registres PPU ===
puts "=== Registres PPU (après #{frames} frames) ==="
puts "PPUCTRL: $#{ppu.instance_variable_get(:@reg_control).to_s(16).upcase.rjust(2, '0')}"
puts "PPUMASK: $#{ppu.instance_variable_get(:@reg_mask).to_s(16).upcase.rjust(2, '0')}"
puts "PPUSTATUS: $#{ppu.instance_variable_get(:@reg_status).to_s(16).upcase.rjust(2, '0')}"

# Lire la VRAM directement via le PPU bus
ppu_bus = ppu.instance_variable_get(:@bus)

puts
puts "=== Palette RAM ==="
print "BG: "
16.times do |i|
  val = ppu_bus.read(0x3F00 + i)
  print "$#{val.to_s(16).upcase.rjust(2, '0')} "
end
puts
print "SP: "
16.times do |i|
  val = ppu_bus.read(0x3F10 + i)
  print "$#{val.to_s(16).upcase.rjust(2, '0')} "
end
puts

puts
puts "=== Nametable 0 (premiers 64 bytes) ==="
4.times do |row|
  16.times do |col|
    val = ppu_bus.read(0x2000 + row * 16 + col)
    print "#{val.to_s(16).upcase.rjust(2, '0')} "
  end
  puts
end

puts
puts "=== Pattern Table 0 (premiers 16 bytes = tile 0) ==="
16.times do |i|
  val = ppu_bus.read(i)
  print "#{val.to_s(16).upcase.rjust(2, '0')} "
end
puts

puts
puts "=== Pattern Table 1 (premiers 16 bytes) ==="
16.times do |i|
  val = ppu_bus.read(0x1000 + i)
  print "#{val.to_s(16).upcase.rjust(2, '0')} "
end
puts

puts
puts "=== CHR-ROM premiers 32 bytes ==="
32.times do |i|
  val = cartridge.ppu_read(i)
  print "#{val.to_s(16).upcase.rjust(2, '0')} "
  puts if (i + 1) % 16 == 0
end

puts
puts "=== Framebuffer (pixels uniques) ==="
unique = ppu.frame_buffer.uniq.sort
puts "#{unique.length} couleurs uniques: #{unique.map { |c| '$' + c.to_s(16).upcase.rjust(2, '0') }.join(', ')}"

puts
puts "=== OAM (premiers 8 sprites) ==="
oam = ppu.instance_variable_get(:@oam)
8.times do |i|
  y    = oam[i * 4]
  tile = oam[i * 4 + 1]
  attr = oam[i * 4 + 2]
  x    = oam[i * 4 + 3]
  puts "  Sprite #{i}: Y=#{y} Tile=$#{tile.to_s(16).upcase.rjust(2,'0')} Attr=$#{attr.to_s(16).upcase.rjust(2,'0')} X=#{x}"
end

puts
puts "=== État CPU ==="
puts cpu.state_string