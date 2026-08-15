# lib/display/frame_buffer.rb

require_relative "../ppu/palette"

class FrameBuffer
  WIDTH  = 256
  HEIGHT = 240

  attr_reader :pixels

  def initialize
    # Tableau de pixels ARGB 32-bit
    @pixels = Array.new(WIDTH * HEIGHT, 0xFF000000)
  end

  # Convertit les indices de palette NES en pixels RGB
  def update_from_ppu(ppu_buffer)
    ppu_buffer.each_with_index do |color_index, i|
      @pixels[i] = NESPalette.argb(color_index)
    end
  end

  def pixel_at(x, y)
    @pixels[y * WIDTH + x]
  end

  def rgb_at(x, y)
    NESPalette.rgb(@pixels[y * WIDTH + x] & 0x3F)
  end
end