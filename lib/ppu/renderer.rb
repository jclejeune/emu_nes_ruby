# lib/ppu/renderer.rb

module Renderer
  def render_frame_simple
  @universal_bg = @bus.read(0x3F00) & 0x3F
  @frame_buffer.fill(@universal_bg)

  render_background_simple if show_background?
  render_sprites_simple    if show_sprites?
end

  private

  def render_background_simple
    base_nametable = 0x2000 | ((@reg_control & 0x03) * 0x400)
    pattern_base   = (@reg_control & 0x10) != 0 ? 0x1000 : 0x0000

    30.times do |tile_y|
      32.times do |tile_x|
        tile_index = @bus.read(base_nametable + tile_y * 32 + tile_x)
        palette_id = background_palette_for_tile(base_nametable, tile_x, tile_y)

        8.times do |row|
          plane0 = @bus.read(pattern_base + tile_index * 16 + row)
          plane1 = @bus.read(pattern_base + tile_index * 16 + row + 8)

          8.times do |col|
            bit   = 7 - col
            pixel = (((plane1 >> bit) & 0x01) << 1) | ((plane0 >> bit) & 0x01)

            screen_x = tile_x * 8 + col
            screen_y = tile_y * 8 + row
            next if screen_x >= 256 || screen_y >= 240

            color_index =
              if pixel == 0
                @universal_bg
              else
                @bus.read(0x3F00 + palette_id * 4 + pixel) & 0x3F
              end

            @frame_buffer[screen_y * 256 + screen_x] = color_index
          end
        end
      end
    end
  end

  def background_palette_for_tile(base_nametable, tile_x, tile_y)
    attribute_addr = base_nametable + 0x03C0 + (tile_y / 4) * 8 + (tile_x / 4)
    attribute_byte = @bus.read(attribute_addr)

    quadrant_x = (tile_x % 4) / 2
    quadrant_y = (tile_y % 4) / 2
    shift = (quadrant_y * 4) + (quadrant_x * 2)

    (attribute_byte >> shift) & 0x03
  end

  def render_sprites_simple
    sprite_height = (@reg_control & 0x20) != 0 ? 16 : 8

    63.downto(0) do |i|
      sprite_y   = @oam[i * 4] + 1
      tile_index = @oam[i * 4 + 1]
      attr       = @oam[i * 4 + 2]
      sprite_x   = @oam[i * 4 + 3]

      next if sprite_y >= 240

      flip_h     = (attr & 0x40) != 0
      flip_v     = (attr & 0x80) != 0
      behind_bg  = (attr & 0x20) != 0
      palette_id = 4 + (attr & 0x03)

      sprite_height.times do |row|
        src_row = flip_v ? (sprite_height - 1 - row) : row

        pattern_addr =
          if sprite_height == 8
            table = (@reg_control & 0x08) != 0 ? 0x1000 : 0x0000
            table + tile_index * 16 + src_row
          else
            table = (tile_index & 0x01) != 0 ? 0x1000 : 0x0000
            tile  = tile_index & 0xFE
            local_row = src_row
            if local_row >= 8
              tile += 1
              local_row -= 8
            end
            table + tile * 16 + local_row
          end

        plane0 = @bus.read(pattern_addr)
        plane1 = @bus.read(pattern_addr + 8)

        8.times do |col|
          src_col = flip_h ? col : (7 - col)
          pixel = (((plane1 >> src_col) & 0x01) << 1) | ((plane0 >> src_col) & 0x01)
          next if pixel == 0

          x = sprite_x + col
          y = sprite_y + row
          next if x < 0 || x >= 256 || y < 0 || y >= 240

          dst = y * 256 + x

          # Si le sprite est "behind" et qu'on a déjà un tile non-transparent, skip
          next if behind_bg && @frame_buffer[dst] != @universal_bg

          color_index = @bus.read(0x3F00 + palette_id * 4 + pixel) & 0x3F
          @frame_buffer[dst] = color_index
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