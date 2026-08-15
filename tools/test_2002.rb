# tools/test_2002.rb
$LOAD_PATH.unshift(File.join(__dir__, "..", "lib"))
require "bus/bus"
require "cpu/cpu"
require "ppu/ppu"
require "cartridge/cartridge"
require "input/joypad"

ppu = PPU.new
bus = Bus.new(ppu)
cpu = CPU.new(bus)
cpu.reset
cpu.pc = 0x0000

# LDA $2002
bus.write(0x0000, 0xAD)
bus.write(0x0001, 0x02)
bus.write(0x0002, 0x20)

ppu.instance_variable_set(:@reg_status, 0x80)
cpu.step
puts "A après LDA $2002 (VBlank=1) : $#{cpu.a.to_s(16).upcase.rjust(2, '0')}"
puts(cpu.a & 0x80 != 0 ? "OK — le CPU voit le VBlank" : "BUG — $2002 ne remonte pas")

cpu.pc = 0x0000
cpu.step
puts "2e LDA $2002 : $#{cpu.a.to_s(16).upcase.rjust(2, '0')} (attendu $00)"