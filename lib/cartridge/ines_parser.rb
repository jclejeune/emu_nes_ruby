# lib/cartridge/ines_parser.rb

class INESParser
  INES_MAGIC = [0x4E, 0x45, 0x53, 0x1A].freeze # "NES\x1A"
  PRG_BANK_SIZE = 16_384  # 16KB
  CHR_BANK_SIZE = 8_192   # 8KB

  ParsedROM = Struct.new(
    :prg_rom,
    :chr_rom,
    :mapper_id,
    :prg_banks,
    :chr_banks,
    :mirror_mode,   # :horizontal, :vertical, :four_screen
    :battery,
    :trainer,
    keyword_init: true
  )

  class ParseError < StandardError; end

  def self.parse(path)
    data = File.binread(path).bytes

    validate_header!(data)

    prg_banks   = data[4]
    chr_banks   = data[5]
    flags6      = data[6]
    flags7      = data[7]

    mapper_id   = (flags7 & 0xF0) | (flags6 >> 4)
    mirror_mode = parse_mirror_mode(flags6)
    battery     = (flags6 & 0x02) != 0
    trainer     = (flags6 & 0x04) != 0

    offset = 16
    offset += 512 if trainer

    prg_size = prg_banks * PRG_BANK_SIZE
    chr_size = chr_banks * CHR_BANK_SIZE

    prg_rom = data[offset, prg_size]
    offset += prg_size

    chr_rom = if chr_banks > 0
                data[offset, chr_size]
              else
                # CHR RAM (8KB)
                Array.new(CHR_BANK_SIZE, 0x00)
              end

    ParsedROM.new(
      prg_rom:     prg_rom,
      chr_rom:     chr_rom,
      mapper_id:   mapper_id,
      prg_banks:   prg_banks,
      chr_banks:   chr_banks,
      mirror_mode: mirror_mode,
      battery:     battery,
      trainer:     trainer
    )
  end

  private

  def self.validate_header!(data)
    raise ParseError, "Fichier trop petit" if data.length < 16
    raise ParseError, "Header iNES invalide" unless data[0, 4] == INES_MAGIC
  end

  def self.parse_mirror_mode(flags6)
    if (flags6 & 0x08) != 0
      :four_screen
    elsif (flags6 & 0x01) != 0
      :vertical
    else
      :horizontal
    end
  end
end