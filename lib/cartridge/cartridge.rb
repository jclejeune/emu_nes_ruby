# lib/cartridge/cartridge.rb

require_relative "ines_parser"
require_relative "mappers/mapper_000"

class Cartridge
  attr_reader :prg_rom, :chr_rom, :mapper, :mirror_mode

  MAPPER_CLASSES = {
    0 => Mapper000
  }.freeze

  class UnsupportedMapper < StandardError; end

  def self.load(path)
    new(path)
  end

  def initialize(path)
    parsed = INESParser.parse(path)

    @prg_rom     = parsed.prg_rom
    @chr_rom     = parsed.chr_rom
    @mirror_mode = parsed.mirror_mode
    @mapper_id   = parsed.mapper_id

    mapper_class = MAPPER_CLASSES[@mapper_id]
    raise UnsupportedMapper, "Mapper #{@mapper_id} non supporté" unless mapper_class

    @mapper = mapper_class.new(parsed.prg_banks, parsed.chr_banks)
  end

  def cpu_read(address)
    mapped = @mapper.map_cpu_read(address)
    return 0x00 unless mapped

    @prg_rom[mapped] || 0x00
  end

  def cpu_write(address, data)
    mapped = @mapper.map_cpu_write(address)
    return unless mapped

    @prg_rom[mapped] = data
  end

  def ppu_read(address)
    mapped = @mapper.map_ppu_read(address)
    return 0x00 unless mapped

    @chr_rom[mapped] || 0x00
  end

  def ppu_write(address, data)
    mapped = @mapper.map_ppu_write(address)
    return unless mapped

    @chr_rom[mapped] = data
  end

  def info
    "Mapper: #{@mapper_id} | " \
    "PRG: #{@prg_rom.length / 1024}KB | " \
    "CHR: #{@chr_rom.length / 1024}KB | " \
    "Mirror: #{@mirror_mode}"
  end
end