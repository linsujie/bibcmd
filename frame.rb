#!/usr/bin/env ruby
# encoding: utf-8

# The window with frame
class Framewin
  attr_reader :cont
  attr_accessor :framewin

  public

  def initialize(height, width, lsft, csft, frame = false)
    @frame = frame
    @h = height - 1
    @w = width - 1

    @framewin = Window.new(height + 2, width + 2, lsft, csft) if @frame

    lsft, csft = lsft + 1, csft + 1 if @frame
    @cont = Window.new(height, width, lsft, csft)
  end

  def refresh(pos = false)
    drawframe(pos) if @frame
    @cont.refresh
  end

  def freshframe
    @framewin.box(@frame[0], @frame[1])
    @framewin.refresh
  end

  private

  def drawframe(pos)
    getbkg(pos)
    freshframe

    @cont.setpos(0, 0)
    @cont.addstr(@bkgd)
  end

  def getbkg(pos)
    @bkgd = ''
    line, col = pos || [@h, @w]
    areabf(line, col) { |ln, cl| @bkgd << inchar(ln, cl) }
  end

  def areabf(line, col)
    (0..line - 1).each { |ln| (0..@w).each { |cl| yield(ln, cl) } }
    (0..col).each { |cl| yield(line, cl) }
  end

  def inchar(line, col)
    @cont.setpos(line, col)
    @cont.inch
  end
end
