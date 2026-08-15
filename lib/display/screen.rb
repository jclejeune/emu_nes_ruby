# lib/display/screen.rb

require_relative "frame_buffer"

class Screen
  WIDTH  = 256
  HEIGHT = 240
  SCALE  = 3

  def initialize
    @frame_buffer  = FrameBuffer.new
    @sdl_available = false

    begin
      require "sdl2"
      init_sdl
      @sdl_available = true
      puts "✅ SDL2 chargé — fenêtre #{WIDTH * SCALE}×#{HEIGHT * SCALE}"
    rescue LoadError
      puts "⚠️  SDL2 non disponible → mode headless"
    end
  end

  def render(ppu_buffer)
    @frame_buffer.update_from_ppu(ppu_buffer)
    render_sdl if @sdl_available
  end

  def poll_events(joypad1, joypad2)
    if @sdl_available
      poll_sdl_events(joypad1, joypad2)
    else
      true
    end
  end

  def cleanup
    return unless @sdl_available
    @renderer&.destroy
    @window&.destroy
    SDL2.quit
  end

  private

  def init_sdl
    SDL2.init(SDL2::INIT_VIDEO)

    @window = SDL2::Window.create(
      "NES Emulator",
      SDL2::Window::POS_CENTERED,
      SDL2::Window::POS_CENTERED,
      WIDTH * SCALE,
      HEIGHT * SCALE,
      0
    )

    @renderer = @window.create_renderer(
      -1,
      SDL2::Renderer::Flags::ACCELERATED
    )

    # Pré-calculer les rectangles destination pour chaque pixel
    # Chaque pixel NES = un carré SCALE×SCALE sur l'écran
    @rects = Array.new(WIDTH * HEIGHT) do |i|
      x = (i % WIDTH) * SCALE
      y = (i / WIDTH) * SCALE
      SDL2::Rect.new(x, y, SCALE, SCALE)
    end
  end

  def render_sdl
    @renderer.draw_color = [0, 0, 0]
    @renderer.clear

    pixels = @frame_buffer.pixels

    pixels.each_with_index do |argb, i|
      r = (argb >> 16) & 0xFF
      g = (argb >> 8)  & 0xFF
      b = argb         & 0xFF

      # Skip les pixels noirs (optimisation)
      next if r == 0 && g == 0 && b == 0

      @renderer.draw_color = [r, g, b]
      @renderer.fill_rect(@rects[i])
    end

    @renderer.present
  end

  def poll_sdl_events(joypad1, _joypad2)
    while (event = SDL2::Event.poll)
      case event
      when SDL2::Event::Quit
        return false
      when SDL2::Event::KeyDown
        return false if event.sym == SDL2::Key::ESCAPE
        handle_key(joypad1, event.sym, :press)
      when SDL2::Event::KeyUp
        handle_key(joypad1, event.sym, :release)
      end
    end
    true
  end

  def key_map
    @key_map ||= {
      SDL2::Key::Z      => :a,
      SDL2::Key::X      => :b,
      SDL2::Key::RSHIFT => :select,
      SDL2::Key::RETURN => :start,
      SDL2::Key::UP     => :up,
      SDL2::Key::DOWN   => :down,
      SDL2::Key::LEFT   => :left,
      SDL2::Key::RIGHT  => :right,
    }
  end

  def handle_key(joypad, sym, action)
    button = key_map[sym]
    return unless button

    if action == :press
      joypad.press(button)
    else
      joypad.release(button)
    end
  end
end