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

# Warmup 60 frames pour laisser le jeu s'initialiser
60.times do
  loop do
    c = cpu.step
    (c * 3).times do
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

puts "=== Après 60 frames de warmup ==="
puts "PC: $#{cpu.pc.to_s(16).upcase.rjust(4,'0')}"

# Compter les PC uniques sur les 10000 prochaines instructions
pc_visits = Hash.new(0)
last_pcs  = []

10_000.times do
  pc_visits[cpu.pc] += 1
  last_pcs << cpu.pc
  last_pcs.shift if last_pcs.length > 20
  
  c = cpu.step
  (c * 3).times do
    ppu.step
    if ppu.nmi_triggered?
      cpu.nmi
      ppu.clear_nmi
    end
  end
end

puts
puts "=== Top 10 PC les plus visités (sur 10000 instructions) ==="
pc_visits.sort_by { |_, v| -v }.first(10).each do |pc, count|
  puts "  $#{pc.to_s(16).upcase.rjust(4,'0')} : #{count} fois"
end

puts
puts "=== Derniers 20 PC ==="
last_pcs.each do |pc|
  puts "  $#{pc.to_s(16).upcase.rjust(4,'0')}"
end

puts
puts "=== État CPU actuel ==="
puts cpu.state_string

puts
puts "=== État PPU ==="
puts "PPUCTRL: $#{ppu.instance_variable_get(:@reg_control).to_s(16).upcase.rjust(2,'0')}"
puts "PPUMASK: $#{ppu.instance_variable_get(:@reg_mask).to_s(16).upcase.rjust(2,'0')}"
puts "PPUSTATUS: $#{ppu.instance_variable_get(:@reg_status).to_s(16).upcase.rjust(2,'0')}"
puts "Scanline: #{ppu.instance_variable_get(:@scanline)}"
puts "Frame count: #{ppu.instance_variable_get(:@frame_count)}"
puts "NMI triggered? #{ppu.nmi_triggered?}"
