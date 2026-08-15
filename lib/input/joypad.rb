# lib/input/joypad.rb

class Joypad
  BUTTONS = %i[a b select start up down left right].freeze

  def initialize
    @buttons = 0x00
    @strobe = false
    @shift_register = 0x00
  end

  def read
    return @buttons & 0x01 if @strobe
    value = @shift_register & 0x01
    @shift_register = (@shift_register >> 1) | 0x80
    value
  end

  def write(data)
    @strobe = (data & 0x01) != 0
    reload_shift_register if @strobe
  end

  def press(button)
    index = BUTTONS.index(button)
    return unless index

    @buttons |= (1 << index)
  end

  def release(button)
    index = BUTTONS.index(button)
    return unless index

    @buttons &= ~(1 << index) & 0xFF
  end

  private

  def reload_shift_register
    @shift_register = @buttons
  end
end