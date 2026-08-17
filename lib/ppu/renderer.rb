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

  # Dessine le fond en tenant compte du scroll (registres loopy @t / @x).
  #
  # Principe : on peint une grille de tuiles alignee sur la grille NES
  # (33 colonnes x 31 lignes, soit 264x248 px) dans un buffer temporaire,
  # en partant de la tuile de @t et en avancant tuile par tuile avec le
  # meme algorithme de wrap "coarse scroll" que le hardware (bascule de
  # nametable a 31/29 tuiles). Une fois cette grille non decalee dessinee,
  # on la recopie dans le frame buffer final avec un simple offset de
  # (fine_x, fine_y) pixels : c'est ce decalage sous-tuile qui donne
  # l'impression de defilement fluide (pixel par pixel) plutot que
  # tuile par tuile.
  #
  # Limite connue : on echantillonne @t une seule fois par frame (au
  # moment du render), donc un jeu qui change le scroll en cours de
  # frame (ex: split HUD/aire de jeu) ne sera pas rendu correctement
  # pour les deux zones a la fois. A ameliorer plus tard en rendant
  # ligne par ligne si besoin.
  def render_background_fast(pal)
    cache     = @tile_cache
    opaque    = @bg_opaque
    buf       = @frame_buffer
    table_off = (@reg_control & 0x10) != 0 ? 256 : 0
    ubg       = @universal_bg

    fine_x = @x
    fine_y = (@t >> 12) & 0x07

    cols  = 33               # 264 px : assez pour couvrir 256 + fine_x
    rows  = 31               # 248 px : assez pour couvrir 240 + fine_y
    tmp_w = cols * 8

    @bg_tmp_color  ||= Array.new(tmp_w * rows * 8)
    @bg_tmp_opaque ||= Array.new(tmp_w * rows * 8)
    tmp_color  = @bg_tmp_color
    tmp_opaque = @bg_tmp_opaque

    row_v = @t
    rows.times do |ty|
      col_v = row_v
      sy    = ty * 8
      cols.times do |tx|
        nt_addr   = 0x2000 | (col_v & 0x0FFF)
        attr_addr = 0x23C0 | (col_v & 0x0C00) | ((col_v >> 4) & 0x38) | ((col_v >> 2) & 0x07)

        tile  = @bus.read(nt_addr)
        attr  = @bus.read(attr_addr)

        coarse_x = col_v & 0x1F
        coarse_y = (col_v >> 5) & 0x1F
        shift    = ((coarse_y & 2) << 1) | (coarse_x & 2)
        p_off    = ((attr >> shift) & 0x03) * 4
        px       = cache[table_off + tile]

        base = sy * tmp_w + tx * 8
        8.times do |r|
          o    = r << 3
          line = base + r * tmp_w
          8.times do |c|
            p = px[o + c]
            d = line + c
            if p == 0
              tmp_color[d]  = ubg
              tmp_opaque[d] = false
            else
              tmp_color[d]  = pal[p_off + p] & 0x3F
              tmp_opaque[d] = true
            end
          end
        end

        col_v = increment_coarse_x(col_v)
      end
      row_v = increment_coarse_y(row_v)
    end

    # Recopie avec le decalage fine_x/fine_y : c'est ici que "la camera bouge"
    240.times do |y|
      src_row = (y + fine_y) * tmp_w
      dst_row = y * 256
      256.times do |x|
        s = src_row + x + fine_x
        d = dst_row + x
        buf[d]    = tmp_color[s]
        opaque[d] = tmp_opaque[s]
      end
    end
  end

  # Avance "v" d'une tuile en X, avec bascule de nametable horizontal a 31.
  # Version pure (sans etat) de increment_scroll_x, utilisable a la volee
  # pour balayer une rangee de tuiles au moment du rendu.
  def increment_coarse_x(v)
    if (v & 0x001F) == 31
      (v & ~0x001F) ^ 0x0400
    else
      v + 1
    end
  end

  # Avance "v" d'une tuile en Y, avec bascule de nametable vertical a 29
  # (et le cas particulier des lignes 29-31 qui debordent des attributs).
  # Version pure (sans etat) de increment_scroll_y, sans le fine Y puisqu'on
  # avance ici tuile par tuile (le fine Y est gere separement en offset px).
  def increment_coarse_y(v)
    y = (v & 0x03E0) >> 5
    if y == 29
      y = 0
      v ^= 0x0800
    elsif y == 31
      y = 0
    else
      y += 1
    end
    (v & ~0x03E0) | (y << 5)
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