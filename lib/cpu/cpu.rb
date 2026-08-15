# lib/cpu/cpu.rb

require_relative "addressing_modes"
require_relative "instructions"
require_relative "interrupts"
require_relative "opcodes_table"

class CPU
  include AddressingModes
  include Instructions
  include Interrupts
  include OpcodesTable

  attr_accessor :a, :x, :y, :sp, :pc, :status, :cycles

  FLAGS = {
    C: (1 << 0),  # Carry
    Z: (1 << 1),  # Zero
    I: (1 << 2),  # Interrupt Disable
    D: (1 << 3),  # Decimal (ignoré sur 2A03)
    B: (1 << 4),  # Break
    U: (1 << 5),  # Unused (toujours 1)
    V: (1 << 6),  # Overflow
    N: (1 << 7),  # Negative
  }.freeze

  ADDR_MODE_DISPATCH = {
    imp: :addr_implicit,
    acc: :addr_accumulator,
    imm: :addr_immediate,
    zp:  :addr_zero_page,
    zpx: :addr_zero_page_x,
    zpy: :addr_zero_page_y,
    abs: :addr_absolute,
    abx: :addr_absolute_x,
    aby: :addr_absolute_y,
    ind: :addr_indirect,
    izx: :addr_indexed_indirect,
    izy: :addr_indirect_indexed,
    rel: :addr_relative,
  }.freeze

  # Instructions qui ajoutent +1 cycle si page crossing
  PAGE_CROSS_INSTRUCTIONS = %i[
    lda ldx ldy adc sbc cmp and_op ora eor
    lax
  ].freeze

  def initialize(bus)
    @bus = bus
    @a = 0x00
    @x = 0x00
    @y = 0x00
    @sp = 0xFD
    @pc = 0x0000
    @status = 0x24
    @cycles = 0
    @total_cycles = 0
  end

  # ===== Flag helpers =====

  def set_flag(flag, condition)
    if condition
      @status |= FLAGS[flag]
    else
      @status &= ~FLAGS[flag] & 0xFF
    end
  end

  def flag?(flag)
    (@status & FLAGS[flag]) != 0
  end

  # ===== Bus access =====

  def read(address)
    @bus.read(address)
  end

  def write(address, data)
    @bus.write(address, data)
  end

  # ===== Exécution =====

  def step
    opcode = read(@pc)
    @pc = (@pc + 1) & 0xFFFF

    entry = OPCODES[opcode]

    unless entry
      puts "OPCODE INCONNU: 0x#{opcode.to_s(16).upcase.rjust(2, '0')} à $#{((@pc - 1) & 0xFFFF).to_s(16).upcase.rjust(4, '0')}"
      return 2  # NOP de secours
    end

    instruction, addr_mode, base_cycles = entry
    @cycles = base_cycles

    # Résoudre l'adresse
    addr_method = ADDR_MODE_DISPATCH[addr_mode]
    addr, page_crossed = send(addr_method)

    # Ajouter cycle si page crossing sur instructions éligibles
    if page_crossed && PAGE_CROSS_INSTRUCTIONS.include?(instruction)
      @cycles += 1
    end

    # Exécuter l'instruction
    send(instruction, addr, page_crossed)

    @total_cycles += @cycles
    @cycles
  end

  # ===== Debug =====

  def state_string
    flags_str = "#{flag?(:N) ? 'N' : '.'}"\
                "#{flag?(:V) ? 'V' : '.'}"\
                "-"\
                "#{flag?(:B) ? 'B' : '.'}"\
                "#{flag?(:D) ? 'D' : '.'}"\
                "#{flag?(:I) ? 'I' : '.'}"\
                "#{flag?(:Z) ? 'Z' : '.'}"\
                "#{flag?(:C) ? 'C' : '.'}"

    format(
      "PC:%04X A:%02X X:%02X Y:%02X SP:%02X P:%02X [%s] CYC:%d",
      @pc, @a, @x, @y, @sp, @status, flags_str, @total_cycles
    )
  end

  # Format compatible avec nestest.log
  def nestest_log_line
    opcode = @bus.debug_read(@pc)
    entry = OPCODES[opcode]
    inst_name = entry ? entry[0].to_s.upcase.gsub("_OP", "") : "???"

    format(
      "%04X  %02X  %-4s  A:%02X X:%02X Y:%02X P:%02X SP:%02X CYC:%d",
      @pc, opcode, inst_name, @a, @x, @y, @status, @sp, @total_cycles
    )
  end
end