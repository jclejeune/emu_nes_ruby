# test/cpu/test_cpu.rb

require "minitest/autorun"
require_relative "../../lib/bus/bus"
require_relative "../../lib/cpu/cpu"
require_relative "../../lib/input/joypad"

class TestCPU < Minitest::Test
  def setup
    @bus = Bus.new
    @cpu = CPU.new(@bus)
    @cpu.reset
    # On pointe vers la RAM pour les tests
    @cpu.pc = 0x0000
  end

  def load_program(*bytes)
    bytes.each_with_index do |b, i|
      @bus.write(i, b)
    end
    @cpu.pc = 0x0000
  end

  # ===== LDA =====

  def test_lda_immediate
    load_program(0xA9, 0x42)
    @cpu.step
    assert_equal 0x42, @cpu.a
    assert_equal false, @cpu.flag?(:Z)
    assert_equal false, @cpu.flag?(:N)
  end

  def test_lda_zero
    load_program(0xA9, 0x00)
    @cpu.step
    assert_equal 0x00, @cpu.a
    assert_equal true, @cpu.flag?(:Z)
    assert_equal false, @cpu.flag?(:N)
  end

  def test_lda_negative
    load_program(0xA9, 0x80)
    @cpu.step
    assert_equal 0x80, @cpu.a
    assert_equal false, @cpu.flag?(:Z)
    assert_equal true, @cpu.flag?(:N)
  end

  # ===== LDX =====

  def test_ldx_immediate
    load_program(0xA2, 0x33)
    @cpu.step
    assert_equal 0x33, @cpu.x
  end

  # ===== LDY =====

  def test_ldy_immediate
    load_program(0xA0, 0x55)
    @cpu.step
    assert_equal 0x55, @cpu.y
  end

  # ===== Transferts =====

  def test_tax
    load_program(0xA9, 0x42, 0xAA) # LDA #$42, TAX
    @cpu.step
    @cpu.step
    assert_equal 0x42, @cpu.x
  end

  def test_tay
    load_program(0xA9, 0x42, 0xA8)
    @cpu.step
    @cpu.step
    assert_equal 0x42, @cpu.y
  end

  # ===== ADC =====

  def test_adc_simple
    load_program(0xA9, 0x10, 0x69, 0x20) # LDA #$10, ADC #$20
    @cpu.step
    @cpu.step
    assert_equal 0x30, @cpu.a
    assert_equal false, @cpu.flag?(:C)
  end

  def test_adc_carry
    load_program(0xA9, 0xFF, 0x69, 0x01) # LDA #$FF, ADC #$01
    @cpu.step
    @cpu.step
    assert_equal 0x00, @cpu.a
    assert_equal true, @cpu.flag?(:C)
    assert_equal true, @cpu.flag?(:Z)
  end

  def test_adc_overflow
    load_program(0xA9, 0x7F, 0x69, 0x01) # LDA #$7F, ADC #$01
    @cpu.step
    @cpu.step
    assert_equal 0x80, @cpu.a
    assert_equal true, @cpu.flag?(:V)
    assert_equal true, @cpu.flag?(:N)
  end

  # ===== SBC =====

  def test_sbc_simple
    load_program(0x38, 0xA9, 0x20, 0xE9, 0x10) # SEC, LDA #$20, SBC #$10
    @cpu.step  # SEC
    @cpu.step  # LDA
    @cpu.step  # SBC
    assert_equal 0x10, @cpu.a
    assert_equal true, @cpu.flag?(:C) # Pas d'emprunt
  end

  # ===== INC / DEC =====

  def test_inx
    load_program(0xA2, 0x05, 0xE8) # LDX #$05, INX
    @cpu.step
    @cpu.step
    assert_equal 0x06, @cpu.x
  end

  def test_dex
    load_program(0xA2, 0x05, 0xCA) # LDX #$05, DEX
    @cpu.step
    @cpu.step
    assert_equal 0x04, @cpu.x
  end

  def test_dex_underflow
    load_program(0xA2, 0x00, 0xCA) # LDX #$00, DEX
    @cpu.step
    @cpu.step
    assert_equal 0xFF, @cpu.x
    assert_equal true, @cpu.flag?(:N)
  end

  # ===== Branchements =====

  def test_beq_taken
    load_program(0xA9, 0x00, 0xF0, 0x02, 0xA9, 0x42, 0xA9, 0x99)
    # LDA #$00  → Z=1
    # BEQ +2    → saute les 2 prochains bytes
    # (skip) LDA #$42
    # LDA #$99  ← atterrit ici
    @cpu.step  # LDA #$00
    @cpu.step  # BEQ +2
    @cpu.step  # LDA #$99
    assert_equal 0x99, @cpu.a
  end

  def test_bne_not_taken
    load_program(0xA9, 0x00, 0xD0, 0x02, 0xA9, 0x42)
    # LDA #$00  → Z=1
    # BNE +2    → pas pris (Z=1)
    # LDA #$42  ← continue ici
    @cpu.step
    @cpu.step
    @cpu.step
    assert_equal 0x42, @cpu.a
  end

  # ===== Stack =====

  def test_pha_pla
    load_program(0xA9, 0x42, 0x48, 0xA9, 0x00, 0x68)
    # LDA #$42, PHA, LDA #$00, PLA
    @cpu.step  # LDA #$42
    @cpu.step  # PHA
    @cpu.step  # LDA #$00
    assert_equal 0x00, @cpu.a
    @cpu.step  # PLA
    assert_equal 0x42, @cpu.a
  end

  # ===== JSR / RTS =====

  def test_jsr_rts
    # Met RTS à l'adresse $0300
    @bus.write(0x0300, 0xA9)  # LDA #$FF
    @bus.write(0x0301, 0xFF)
    @bus.write(0x0302, 0x60)  # RTS

    load_program(0x20, 0x00, 0x03, 0xA9, 0x42)
    # JSR $0300 → saute à $0300
    # (à $0300) LDA #$FF, RTS → revient
    # LDA #$42

    @cpu.step  # JSR $0300
    assert_equal 0x0300, @cpu.pc

    @cpu.step  # LDA #$FF (à $0300)
    assert_equal 0xFF, @cpu.a

    @cpu.step  # RTS
    assert_equal 0x0003, @cpu.pc

    @cpu.step  # LDA #$42
    assert_equal 0x42, @cpu.a
  end

  # ===== Flags =====

  def test_sec_clc
    load_program(0x38, 0x18) # SEC, CLC
    @cpu.step
    assert_equal true, @cpu.flag?(:C)
    @cpu.step
    assert_equal false, @cpu.flag?(:C)
  end

  # ===== Cycles =====

  def test_lda_immediate_cycles
    load_program(0xA9, 0x42)
    cycles = @cpu.step
    assert_equal 2, cycles
  end

  def test_lda_absolute_cycles
    load_program(0xAD, 0x00, 0x02)
    cycles = @cpu.step
    assert_equal 4, cycles
  end
end