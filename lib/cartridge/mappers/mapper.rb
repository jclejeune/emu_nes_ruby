# lib/cartridge/mappers/mapper.rb

class Mapper
  attr_reader :prg_banks, :chr_banks

  def initialize(prg_banks, chr_banks)
    @prg_banks = prg_banks
    @chr_banks = chr_banks
  end

  def cpu_read(address)
    raise NotImplementedError
  end

  def cpu_write(address, data)
    raise NotImplementedError
  end

  def ppu_read(address)
    raise NotImplementedError
  end

  def ppu_write(address, data)
    raise NotImplementedError
  end

  # Retourne l'adresse mappée dans le PRG-ROM
  # ou nil si pas géré
  def map_cpu_read(address)
    raise NotImplementedError
  end

  def map_cpu_write(address)
    raise NotImplementedError
  end

  def map_ppu_read(address)
    raise NotImplementedError
  end

  def map_ppu_write(address)
    raise NotImplementedError
  end
end