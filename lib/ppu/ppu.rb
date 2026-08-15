# lib/ppu/ppu.rb

require_relative "ppu_bus"
require_relative "palette"
require_relative "renderer"

class PPU
  include Renderer

  attr_reader :frame_buffer, :frame_complete

  def initialize
    @bus = PPUBus.new
    @frame_buffer = Array.new(256 * 240, 0x00)
    @frame_complete = false

    @reg_control  = 0x00
    @reg_mask     = 0x00
    @reg_status   = 0x00
    @reg_oam_addr = 0x00

    @v = 0x0000
    @t = 0x0000
    @x = 0x00
    @w = false

    @ppu_data_buffer = 0x00

    @oam              = Array.new(256, 0x00)
    @scanline_sprites = []

    @bg_shift_pattern_lo = 0
    @bg_shift_pattern_hi = 0
    @bg_shift_attrib_lo  = 0
    @bg_shift_attrib_hi  = 0

    @bg_next_tile_id     = 0x00
    @bg_next_tile_attrib = 0x00
    @bg_next_tile_lo     = 0x00
    @bg_next_tile_hi     = 0x00

    @bg_transparent = Array.new(256 * 240, true)

    @scanline       = 0
    @cycle          = 0
    @frame_count    = 0
    @nmi_triggered  = false
    @frame_complete = false

    @universal_bg = 0x22
  end

  def connect_cartridge(cartridge)
    @bus.connect_cartridge(cartridge)
  end

  def reset
    @reg_control     = 0
    @reg_mask        = 0
    @reg_status      = 0
    @w               = false
    @ppu_data_buffer = 0
    @scanline        = 0
    @cycle           = 0
    @frame_count     = 0
    @nmi_triggered   = false
    @frame_complete  = false
  end

  # ==========================================================================
  # CPU interface
  # ==========================================================================

  def cpu_read(address)
    address &= 0x0007
    data = 0x00

    case address
    when 2
      data = (@reg_status & 0xE0) | (@ppu_data_buffer & 0x1F)
      @reg_status &= ~0x80
      @w = false
    when 4
      data = @oam[@reg_oam_addr]
    when 7
      data = @ppu_data_buffer
      @ppu_data_buffer = @bus.read(@v)
      if @v >= 0x3F00
        data = @ppu_data_buffer
        @ppu_data_buffer = @bus.read(@v - 0x1000)
      end
      increment_vram_addr
    end

    data
  end

   def cpu_write(address, data)
    address &= 0x0007
    data    &= 0xFF

    case address
    when 0
      nmi_was_off = (@reg_control & 0x80) == 0
      @reg_control = data
      @t = (@t & 0x73FF) | ((data & 0x03) << 10)
      if nmi_was_off && (data & 0x80) != 0 && (@reg_status & 0x80) != 0
        @nmi_triggered = true
      end

    when 1
      @reg_mask = data

    when 3
      @reg_oam_addr = data

    when 4
      @oam[@reg_oam_addr] = data
      @reg_oam_addr = (@reg_oam_addr + 1) & 0xFF

    when 5
      if !@w
        @x = data & 0x07
        @t = (@t & 0x7FE0) | (data >> 3)
        @w = true
      else
        @t = (@t & 0x0C1F) | ((data & 0x07) << 12) | ((data & 0xF8) << 2)
        @w = false
      end

    when 6  # <<< LE BUG EST ICI >>>
      # LOGGING : afficher l'état AVANT modification
      printf "[PPU] $2006 write: data=$%02X | before -> t=$%04X v=$%04X w=%s\n",
             data, @t, @v, @w ? "T" : "F"

      if !@w
        # Premier write : high byte vers t[8-13]
        @t = (@t & 0x00FF) | ((data & 0x3F) << 8)
        @w = true
        printf "     After W1: t=$%04X (set high byte from $%02X)\n", @t, data
      else
        # Deuxième write : low byte vers t[0-7], PUIS t -> v
        @t = (@t & 0xFF00) | data
        @v = @t   # <--- CRITIQUE : ceci DOIT se produire !
        @w = false
        printf "     After W2: t=$%04X v=$%04X (t copied to v!)\n", @t, @v
      end

    when 7
      # Écrire data à l'adresse courante @v, puis incrémenter
      addr_written = @v & 0x3FFF
      is_palette = addr_written >= 0x3F00

      @bus.write(@v, data)

      printf "[PPU] $2007 write: data=$%02X -> v=$%04X (%s)\n",
             data, addr_written,
             is_palette ? "*** PALETTE ***" : "NT/CHR"

      increment_vram_addr
    end
  end

  def write_oam(addr, data)
    @oam[addr & 0xFF] = data & 0xFF
  end

  # ==========================================================================
  # Main tick
  # ==========================================================================

  def step
    # Début du VBlank
    if @scanline == 241 && @cycle == 1
        @reg_status |= 0x80
        @nmi_triggered = true if (@reg_control & 0x80) != 0
    end

    # Pre-render line : clear flags
    if @scanline == 261 && @cycle == 1
        @reg_status &= ~0x80 & 0xFF
        @reg_status &= ~0x40 & 0xFF
        @reg_status &= ~0x20 & 0xFF
        @nmi_triggered = false
    end

    @cycle += 1

    if @cycle >= 341
        @cycle = 0
        @scanline += 1

        if @scanline >= 262
        @scanline = 0
        @frame_count += 1

        render_frame_simple
        @frame_complete = true
        end
    end
    end

  def nmi_triggered?
    @nmi_triggered
  end

  def clear_nmi
    @nmi_triggered = false
  end

  def consume_frame!
    @frame_complete = false
  end

  private

  # ==========================================================================
  # VRAM address helpers
  # ==========================================================================

  def increment_vram_addr
    inc = (@reg_control & 0x04) != 0 ? 32 : 1
    @v = (@v + inc) & 0x7FFF
  end

  def increment_scroll_x
    return unless rendering_enabled?
    if (@v & 0x001F) == 31
      @v &= ~0x001F
      @v ^= 0x0400
    else
      @v += 1
    end
  end

  def increment_scroll_y
    return unless rendering_enabled?
    if (@v & 0x7000) != 0x7000
      @v += 0x1000
    else
      @v &= ~0x7000
      y = (@v & 0x03E0) >> 5
      if y == 29
        y = 0
        @v ^= 0x0800
      elsif y == 31
        y = 0
      else
        y += 1
      end
      @v = (@v & ~0x03E0) | (y << 5)
    end
  end

  def copy_horizontal_bits
    return unless rendering_enabled?
    @v = (@v & ~0x041F) | (@t & 0x041F)
  end

  def copy_vertical_bits
    return unless rendering_enabled?
    @v = (@v & ~0x7BE0) | (@t & 0x7BE0)
  end

  # ==========================================================================
  # Background shift registers
  # ==========================================================================

  def shift_background_registers
    return unless show_background?
    @bg_shift_pattern_lo = (@bg_shift_pattern_lo << 1) & 0xFFFF
    @bg_shift_pattern_hi = (@bg_shift_pattern_hi << 1) & 0xFFFF
    @bg_shift_attrib_lo  = (@bg_shift_attrib_lo  << 1) & 0xFFFF
    @bg_shift_attrib_hi  = (@bg_shift_attrib_hi  << 1) & 0xFFFF
  end

  def load_background_shifters
    @bg_shift_pattern_lo = (@bg_shift_pattern_lo & 0xFF00) | @bg_next_tile_lo
    @bg_shift_pattern_hi = (@bg_shift_pattern_hi & 0xFF00) | @bg_next_tile_hi
    @bg_shift_attrib_lo  = (@bg_shift_attrib_lo  & 0xFF00) |
                           ((@bg_next_tile_attrib & 0x01) != 0 ? 0xFF : 0x00)
    @bg_shift_attrib_hi  = (@bg_shift_attrib_hi  & 0xFF00) |
                           ((@bg_next_tile_attrib & 0x02) != 0 ? 0xFF : 0x00)
  end

  # ==========================================================================
  # Sprite evaluation
  # ==========================================================================

  def evaluate_sprites
    sprite_height = (@reg_control & 0x20) != 0 ? 16 : 8
    @scanline_sprites = []
    found = 0

    64.times do |i|
      sprite_y = @oam[i * 4]
      diff     = @scanline - sprite_y

      next if diff < 0 || diff >= sprite_height

      if found >= 8
        @reg_status |= 0x20
        break
      end

      tile_index = @oam[i * 4 + 1]
      attributes = @oam[i * 4 + 2]
      sprite_x   = @oam[i * 4 + 3]

      row = diff
      row = (sprite_height - 1) - row if (attributes & 0x80) != 0

      if sprite_height == 8
        table = (@reg_control & 0x08) != 0 ? 0x1000 : 0x0000
        pattern_addr = table + (tile_index * 16) + row
      else
        table = (tile_index & 0x01) != 0 ? 0x1000 : 0x0000
        tile  = tile_index & 0xFE
        if row >= 8
          tile += 1
          row  -= 8
        end
        pattern_addr = table + (tile * 16) + row
      end

      @scanline_sprites << {
        index:      i,
        x:          sprite_x,
        attr:       attributes,
        pattern_lo: @bus.read(pattern_addr),
        pattern_hi: @bus.read(pattern_addr + 8)
      }

      found += 1
    end
  end

  def debug_dump_palette_line
    ppu_bus = @bus  # Access au bus interne
    
    bg_colors = []
    16.times { |i| bg_colors << ppu_bus.read(0x3F00 + i) }
    sp_colors = []
    16.times { |i| sp_colors << ppu_bus.read(0x3F10 + i) }
    
    printf "[PALETTE_DUMP] BG:%s | SP:%s | $3F00=$%02X\n",
           bg_colors.map{|v| "$"+v.to_s(16)}.join(" "),
           sp_colors.map{|v| "$"+v.to_s(16)}.join(" "),
           bg_colors[0]
  end

end