# lib/ppu/renderer.rb

module Renderer
  def render_frame_simple
    pal = @bus.palette_ram
    @universal_bg = pal[0] & 0x3F
    @frame_buffer.fill(@universal_bg)

    refresh_tile_cache unless @tile_cache

    render_background_fast(pal) if show_background?
    render_sprites_simple(pal)  if show_sprites?
  end

  private

  # Décode une fois les 512 tiles en tableaux de 64 pixels (0..3)
  def refresh_tile_cache
    chr = @chr_rom
    return unless chr

    @tile_cache = Array.new(512) do |t|
      px   = Array.new(64, 0)
      base = t * 16
      8.times do |row|
        lo = chr[base + row]     || 0
        hi = chr[base + row + 8] || 0
        8.times do |col|
          s = 7 - col
          px[row * 8 + col] = (((hi >> s) & 1) << 1) | ((lo >> s) & 1)
        end
      end
      px
    end
  end

  def render_background_fast(pal)
    cache     = @tile_cache
    buf       = @frame_buffer
    opaque    = @bg_opaque
    base_nt   = 0x2000 | ((@reg_control & 0x03) * 0x400)
    attr_base = base_nt + 0x03C0
    table_off = (@reg_control & 0x10) != 0 ? 256 : 0
    ubg       = @universal_bg

    30.times do |ty|
      sy        = ty * 8
      attr_addr = attr_base + ((ty & 0x1C) << 1)
      32.times do |tx|
        tile  = @bus.read(base_nt + ty * 32 + tx)
        attr  = @bus.read(attr_addr + (tx >> 2))
        shift = ((ty & 2) << 1) | (tx & 2)
        p_off = ((attr >> shift) & 0x03) * 4
        px    = cache[table_off + tile]

        idx = sy * 256 + tx * 8
        8.times do |row|
          o = row << 3
          8.times do |c|
            p = px[o + c]
            d = idx + c
            if p == 0
              buf[d]    = ubg
              opaque[d] = false
            else
              buf[d]    = pal[p_off + p] & 0x3F
              opaque[d] = true
            end
          end
          idx += 256
        end
      end
    end
  end

  def render_sprites_simple(pal)
    sprite_height = (@reg_control & 0x20) != 0 ? 16 : 8
    buf    = @frame_buffer
    opaque = @bg_opaque

    63.downto(0) do |i|
      sprite_y   = @oam[i * 4] + 1
      tile_index = @oam[i * 4 + 1]
      attr       = @oam[i * 4 + 2]
      sprite_x   = @oam[i * 4 + 3]
      next if sprite_y >= 240

      flip_h    = (attr & 0x40) != 0
      flip_v    = (attr & 0x80) != 0
      behind_bg = (attr & 0x20) != 0
      p_off     = 0x10 + (attr & 0x03) * 4

      sprite_height.times do |row|
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
          src_col = flip_h ? col : 7 - col
          p = (((plane1 >> src_col) & 1) << 1) | ((plane0 >> src_col) & 1)
          next if p == 0

          x = sprite_x + col
          y = sprite_y + row
          next if x < 0 || x >= 256 || y < 0 || y >= 240

          d = y * 256 + x

          # Sprite 0 hit
          if i == 0 && x != 255 && show_background? && opaque[d]
            @reg_status |= 0x40
          end

          next if behind_bg && opaque[d]

          buf[d] = pal[p_off + p] & 0x3F
        end
      end
    end
  end

  def rendering_enabled?
    show_background? || show_sprites?
  end

  def show_background?
    (@reg_mask & 0x08) != 0
  end

  def show_sprites?
    (@reg_mask & 0x10) != 0
  end

  def show_background_left8?
    (@reg_mask & 0x02) != 0
  end

  def show_sprites_left8?
    (@reg_mask & 0x04) != 0
  end
end