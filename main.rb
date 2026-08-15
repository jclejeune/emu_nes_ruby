#!/usr/bin/env ruby
# main.rb

$LOAD_PATH.unshift(File.join(__dir__, "lib"))

require "nes"

if ARGV.empty?
  puts "NES Emulator"
  puts "Usage:"
  puts "  ruby main.rb <rom.nes>          Jouer"
  puts "  ruby main.rb --test <rom.nes>   nestest (CPU only)"
  exit 1
end

if ARGV[0] == "--test"
  # Mode test CPU (Phase 1)
  require "bus/bus"
  require "cpu/cpu"
  require "cartridge/cartridge"
  require "input/joypad"

  rom = ARGV[1] || "roms/nestest.nes"
  bus = Bus.new
  cpu = CPU.new(bus)
  cartridge = Cartridge.load(rom)
  bus.insert_cartridge(cartridge)

  cpu.reset
  cpu.pc = 0xC000
  cpu.instance_variable_set(:@total_cycles, 7)

  8991.times do
    puts cpu.nestest_log_line
    cpu.step
  end

  puts "\n$0002=0x#{bus.debug_read(0x0002).to_s(16).upcase.rjust(2,'0')} " \
       "$0003=0x#{bus.debug_read(0x0003).to_s(16).upcase.rjust(2,'0')}"

else
  # Mode normal : émulation complète
  nes = NES.new
  nes.load_rom(ARGV[0])
  nes.power_on
  nes.run
end