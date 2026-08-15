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
    @sdl_available ? poll_sdl_events(joypad1, joypad2) : true
  end

  def cleanup
    return unless @sdl_available
    @renderer&.destroy
    @window&.destroy
    SDL2.quit if SDL2.respond_to?(:quit)
  end

  private

  def init_sdl
    SDL2.init(SDL2::INIT_VIDEO)
    @window = SDL2::Window.create(
      "NES Emulator",
      SDL2::Window::POS_CENTERED, SDL2::Window::POS_CENTERED,
      WIDTH * SCALE, HEIGHT * SCALE, 0
    )
    @renderer = @window.create_renderer(-1, SDL2::Renderer::Flags::ACCELERATED)
  end

  # RLE : un fill_rect par plage de pixels identiques (au lieu de 61 440)
  def render_sdl
    pixels = @frame_buffer.pixels
    @renderer.draw_color = [0, 0, 0]
    @renderer.clear

    y = 0
    while y < HEIGHT
      row = y * WIDTH
      sy  = y * SCALE
      x   = 0
      while x < WIDTH
        color = pixels[row + x]
        x2 = x + 1
        x2 += 1 while x2 < WIDTH && pixels[row + x2] == color

        @renderer.draw_color = [(color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF]
        @renderer.fill_rect(SDL2::Rect.new(x * SCALE, sy, (x2 - x) * SCALE, SCALE))
        x = x2
      end
      y += 1
    end

    @renderer.present
  end

  def poll_sdl_events(joypad1, _joypad2)
    while (event = SDL2::Event.poll)
      case event
      when SDL2::Event::Quit then return false
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
      SDL2::Key::F      => :a,
      SDL2::Key::D      => :b,
      SDL2::Key::RSHIFT => :select,
      SDL2::Key::SPACE  => :start,
      SDL2::Key::UP     => :up,
      SDL2::Key::DOWN   => :down,
      SDL2::Key::LEFT   => :left,
      SDL2::Key::RIGHT  => :right,
    }
  end

  def handle_key(joypad, sym, action)
    button = key_map[sym]
    return unless button
    action == :press ? joypad.press(button) : joypad.release(button)
  end
end