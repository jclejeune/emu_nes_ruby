# lib/clock.rb

class Clock
  NTSC_HZ  = 21_477_272.0
  NTSC_FPS = NTSC_HZ / 4 / 341 / 262   # 60.0988...

  def initialize(report_every: 120)
    @origin       = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @emitted      = 0
    @report_every = report_every
  end

  def wait_next_frame
    @emitted += 1
    target = @origin + @emitted / NTSC_FPS
    now    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    delta  = target - now

    sleep(delta) if delta > 0.0005

    if delta < -0.25
      @origin  = now
      @emitted = 0
    end

    if (@emitted % @report_every).zero?
      measured = @emitted / (now - @origin)
      puts "tempo: #{measured.round(2)} fps (cible #{NTSC_FPS.round(4)})"
    end
  end
end