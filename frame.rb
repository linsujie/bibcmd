#!/usr/bin/env ruby
# encoding: utf-8

require 'ncursesw'

# The window with frame
class Framewin
  include Ncurses
  attr_reader :cont
  attr_accessor :framewin

  public

  def initialize(height, width, lsft, csft, frame = false)
    @corners = [ACS_ULCORNER, ACS_URCORNER, ACS_LLCORNER, ACS_LRCORNER]
    @frame = complete_frame(frame)

    fheight, fwidth = @frame ? [height + 2, width + 2] : [height, width]
    @framewin = WINDOW.new(fheight, fwidth, lsft, csft)
    @framewin.border(*@frame) if @frame

    lsft, csft = lsft + 1, csft + 1 if @frame
    @cont = @framewin.subwin(height, width, lsft, csft)
  end

  def refresh(pos = false)
    @framewin.noutrefresh
    @cont.refresh
  end

  def box(frame)
    @frame = complete_frame(frame)
    @framewin.border(*@frame)
  end

  private

  def complete_frame(frame)
    frame && (frame.map(&:ord).map { |x| [x, x] }.flatten + @corners)
  end
end
