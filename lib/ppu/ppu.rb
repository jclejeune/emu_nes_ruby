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

    @bg_opaque  = Array.new(256 * 240, false)
    @tile_cache = nil
    @chr_rom    = nil
    @last_split = 0
  end

  def connect_cartridge(cartridge)
    @bus.connect_cartridge(cartridge)
    @chr_rom    = cartridge.chr_rom
    @tile_cache = nil
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

  def cpu_read(reg)
  reg &= 7
  data = 0x00

  case reg
  when 2 # $2002
    data = (@reg_status & 0xE0) | (@ppu_data_buffer & 0x1F)
    @reg_status &= 0x7F
    @w = false
  when 4
    data = @oam[@reg_oam_addr]
  when 7
    data = @ppu_data_buffer
    @ppu_data_buffer = @bus.read(@v & 0x3FFF)
    data = @ppu_data_buffer if (@v & 0x3FFF) >= 0x3F00
    increment_vram_addr
  end

  data
end

def cpu_write(reg, data)
  reg  &= 7
  data &= 0xFF

  case reg
  when 0
    nmi_off = (@reg_control & 0x80) == 0
    @reg_control = data
    @t = (@t & 0x73FF) | ((data & 0x03) << 10)
    if nmi_off && (data & 0x80) != 0 && (@reg_status & 0x80) != 0
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
    if @w
      @t = (@t & 0x0C1F) | ((data & 0x07) << 12) | ((data & 0xF8) << 2)
      @w = false
    else
      @x = data & 0x07
      @t = (@t & 0x7FE0) | (data >> 3)
      @w = true
    end
  when 6
    if @w
      @t = (@t & 0xFF00) | data
      @v = @t
      @w = false
    else
      @t = (@t & 0x00FF) | ((data & 0x3F) << 8)
      @w = true
    end
  when 7
    @bus.write(@v & 0x3FFF, data)
    @tile_cache = nil if (@v & 0x3FFF) < 0x2000  # CHR-RAM modifiée → invalider
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
    tick
  end

  # Fait avancer la PPU de n points (dots) d'un coup, via une boucle
  # interne — au lieu de forcer l'appelant a faire n appels de methode
  # separes (chaque appel Ruby a un cout fixe non negligeable, et on en
  # faisait ~89000 par frame rien que pour la comptabilite scanline/cycle).
  # Le comportement (mise a jour de @scanline/@cycle, NMI, rendu, fin de
  # frame) est rigoureusement identique a n appels de #step d'affilee.
  def advance(n)
    n.times { tick }
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

  def tick
    if @scanline == 241 && @cycle == 1
      @reg_status |= 0x80
      @nmi_triggered = true if (@reg_control & 0x80) != 0
    end

    if @scanline == 261 && @cycle == 1
      @reg_status &= 0x1F
      @nmi_triggered = false
    end

    # Sprite 0 hit : detecte a la BONNE ligne pendant le rendu, pas
    # seulement en fin de frame. Des jeux comme SMB attendent ce
    # signal (pour figer le bandeau du haut pendant que le reste
    # scrolle) en tournant en boucle sur $2002 ; s'il n'arrive qu'a
    # la ligne 239, cette boucle d'attente bouffe quasiment tout le
    # budget CPU de la frame et decale le jeu d'une frame sur deux
    # (=> le scroll clignote entre "reset" et "vraie valeur").
    if @cycle == 2 && @scanline >= 0 && @scanline < 240 &&
       (@reg_status & 0x40) == 0 && rendering_enabled?
      check_sprite_zero_hit
    end

    if @scanline == 239 && @cycle == 340
      render_frame_simple
    end

    if @scanline == 261 && @cycle == 340
      @frame_complete = true
      @frame_count += 1
    end

    @cycle += 1
    if @cycle >= 341
      @cycle = 0
      @scanline += 1
      @scanline = 0 if @scanline >= 262
    end
  end

  # Verifie si le sprite OAM #0 recouvre un pixel de fond opaque sur
  # LA LIGNE COURANTE (@scanline), et met le bit 0x40 de PPUSTATUS
  # si oui. Approximation : precis a la ligne pres (pas au cycle/pixel
  # pres comme le vrai hardware), largement suffisant pour debloquer
  # une boucle d'attente de jeu.
  def check_sprite_zero_hit
    sprite_height = (@reg_control & 0x20) != 0 ? 16 : 8
    sprite_y = @oam[0] + 1
    row = @scanline - sprite_y
    return if row < 0 || row >= sprite_height

    tile_index = @oam[1]
    attr       = @oam[2]
    sprite_x   = @oam[3]

    flip_h  = (attr & 0x40) != 0
    flip_v  = (attr & 0x80) != 0
    src_row = flip_v ? (sprite_height - 1 - row) : row

    pattern_addr =
      if sprite_height == 8
        table = (@reg_control & 0x08) != 0 ? 0x1000 : 0x0000
        table + tile_index * 16 + src_row
      else
        table = (tile_index & 0x01) != 0 ? 0x1000 : 0x0000
        tt = tile_index & 0xFE
        lr = src_row
        if lr >= 8
          tt += 1
          lr -= 8
        end
        table + tt * 16 + lr
      end

    plane0 = @bus.read(pattern_addr)
    plane1 = @bus.read(pattern_addr + 8)

    8.times do |col|
      x = sprite_x + col
      next if x >= 255

      src_col = flip_h ? col : (7 - col)
      sp_px = (((plane1 >> src_col) & 1) << 1) | ((plane0 >> src_col) & 1)
      next if sp_px == 0
      next unless background_opaque_at?(x, @scanline)

      @reg_status |= 0x40
      return
    end
  end

  # Opacite du pixel de fond a (x, y) ecran, en tenant compte du
  # scroll courant (@t/@x) — meme logique que render_background_fast
  # mais pour un seul pixel, appele uniquement pendant la fenetre
  # verticale du sprite 0 (quelques lignes par frame, cout negligeable).
  def background_opaque_at?(x, y)
    return false unless show_background?

    fine_x = @x
    fine_y = (@t >> 12) & 0x07
    tot_x  = x + fine_x
    tot_y  = y + fine_y

    v = @t
    (tot_x / 8).times { v = increment_coarse_x(v) }
    (tot_y / 8).times { v = increment_coarse_y(v) }

    nt_addr = 0x2000 | (v & 0x0FFF)
    tile = @bus.read(nt_addr)
    return false unless tile

    refresh_tile_cache unless @tile_cache
    table_off = (@reg_control & 0x10) != 0 ? 256 : 0
    px = @tile_cache[table_off + tile]
    return false unless px

    px[(tot_y % 8) * 8 + (tot_x % 8)] != 0
  end

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
  end

end