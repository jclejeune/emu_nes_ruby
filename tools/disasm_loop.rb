$LOAD_PATH.unshift(File.join(__dir__, "..", "lib"))
require "bus/bus"
require "cpu/cpu"
require "ppu/ppu"
require "cartridge/cartridge"
require "input/joypad"

ppu = PPU.new
bus = Bus.new(ppu)
cart = Cartridge.load("roms/super_mario_bros.nes")
bus.insert_cartridge(cart)

puts "=== Code autour de la boucle CPU ==="
(0x8148..0x8165).each do |addr|
  byte = bus.debug_read(addr)
  printf "$%04X: $%02X\n", addr, byte
end