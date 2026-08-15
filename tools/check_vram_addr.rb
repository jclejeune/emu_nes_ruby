# tools/check_vram_addr.rb

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

# Intercepter les ecritures $2006 (PPUADDR) et $2007 (PPUDATA)
$addr_log = []

# Monkey-patch temporaire du bus pour logger
original_write = bus.method(:write)

bus.define_singleton_method(:write) do |address, data|
  if address >= 0x2000 && address <= 0x2007
    op = (address & 0x0007)
    v_before = ppu.instance_variable_get(:@v)
    t_val   = ppu.instance_variable_get(:@t)
    
    case op
    when 6  # PPUADDR
      w_val = ppu.instance_variable_get(:@w)
      $addr_log << { type: "$2006_W#{w_val ? 2 : 1}", 
                      data: data,
                      v_before: format("$%04X", v_before),
                      t_now:    format("$%04X", t_val),
                      v_after:  "?" }
      # Apres cette ecriture, le PPU DOIT mettre a jour v ou t
      
    when 7  # PPUDATA  
      v_after_exec = ppu.instance_variable_get(:@v)
      $addr_log << { type: "$2007_WRITE",
                      data: data,
                      v_before: format("$%04X", v_before),
                      target:   format("$%04X", v_after_exec & 0x3FFF),
                      is_pal:   (v_after_exec & 0x3FFF) >= 0x3F00 }
    end
  end
  
  original_write.call(address, data)
end

puts "Execution..."
5.times do |frame|
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

puts "\n=== Log des acces $2006 / $2007 ===\n"

# Filtrer : montrer seulement les sequences $2006 -> $2007
seq = []
in_seq = false

$addr_log.each do |entry|
  if entry[:type].start_with?("$2006")
    in_seq = true
    seq << entry
  elsif entry[:type] == "$2007_WRITE" && in_seq
    seq << entry
    
    # Afficher la sequence complete
    seq_str = seq.map do |e|
      if e[:type].include?("$2006")
        "#{e[:type]}=#{e[:data].to_s(16).upcase} [t=#{e[:t_now]}]"
      else
        "D=$#{e[:data].to_s(16).upcase} v=#{e[:target]} #{e[:is_pal] ? '<<< PALETTE!' : ''}"
      end
    end.join(" -> ")
    
    puts seq_str
    
    seq = []
    in_seq = false
  else
    seq.clear if in_seq
  end
end

if $addr_log.empty?
  puts "AUCUN acces $2006/$2007 detecte ! Le bus ne transmet pas correctement."
elsif !$addr_log.any? { |e| e[:is_pal] }
  puts "\n⚠️  Aucune ecriture n'a atteint $3Fxxx !"
  puts "   Verifie si cpu_write($2006) met a jour @v correctement."
else
  count = $addr_log.count { |e| e[:is_pal] }
  puts "\n✅ #{count} ecritures ont atteint la palette."
end