# lib/input/joypad.rb

class Joypad
  BUTTON = %i[a b select start up down left right].freeze

  def initialize
    @buttons = BUTTON.to_h { |b| [b, false] }
    @strobe = false
    @index  = 0
  end

  def press(button)
    @buttons[button] = true if @buttons.key?(button)
  end

  def release(button)
    @buttons[button] = false if @buttons.key?(button)
  end

  def write(data)
    was = @strobe
    @strobe = (data & 1) != 0
    @index = 0 if @strobe || was
  end

  def read
    return bit(:a) if @strobe
    return 0x41 if @index >= 8

    value = bit(BUTTON[@index])
    @index += 1
    value
  end

  private

  def bit(button)
    0x40 | (@buttons[button] ? 1 : 0)
  end
end