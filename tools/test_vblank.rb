$LOAD_PATH.unshift(File.join(__dir__, "..", "lib"))
require "bus/bus"
require "cpu/cpu"
require "ppu/ppu"
require "cartridge/cartridge"
require "input/joypad"

ppu = PPU.new
bus = Bus.new(ppu, nil, Joypad.new, Joypad.new)
cartridge = Cartridge.load("roms/super_mario_bros.nes")
bus.insert_cartridge(cartridge)
ppu.connect_cartridge(cartridge)
CPU.new(bus).reset
ppu.reset

vblank_ons = 0
vblank_offs = 0
last_status = 0

200_000.times do
  ppu.step
  status = ppu.instance_variable_get(:@reg_status) & 0x80
  
  if last_status == 0 && status != 0
    vblank_ons += 1
    puts "VBlank ON at scanline=#{ppu.instance_variable_get(:@scanline)} cycle=#{ppu.instance_variable_get(:@cycle)} frame=#{ppu.instance_variable_get(:@frame_count)}"
  elsif last_status != 0 && status == 0
    vblank_offs += 1
    puts "VBlank OFF at scanline=#{ppu.instance_variable_get(:@scanline)} cycle=#{ppu.instance_variable_get(:@cycle)} frame=#{ppu.instance_variable_get(:@frame_count)}"
  end
  last_status = status
end

puts
puts "Total VBlank ON: #{vblank_ons}"
puts "Total VBlank OFF: #{vblank_offs}"