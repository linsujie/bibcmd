#!/usr/bin/env ruby
# encoding: utf-8

require 'ncursesw'
require_relative 'mentrydata'

# A multiple line entry, you need to prepare a window for it
class Mentry
  include Ncurses
  include Ncurses::Form

  attr_reader :data

  DFT_OPTION = { string: '', headshift: 0, window: nil }

  def initialize(opt)
    @opt = opt
    DFT_OPTION.each_key { |k| @opt[k] = DFT_OPTION[k] unless @opt.key?(k) }
    raise 'please initialize a window for mentry' unless @opt[:window]
    h,w = [], []
    @opt[:window].getmaxyx(h, w)
    @opt[:height], @opt[:width] = h[0], w[0]

    @data = MentryData.new(opt)
  end

  def driver(req_const, *argv)
    @@req_map ||= {
      REQ_PREV_CHAR => :prevchar, REQ_NEXT_CHAR => :nextchar,
      REQ_PREV_WORD => :prevword, REQ_NEXT_WORD => :nextword,
      REQ_BEG_LINE => :begline, REQ_END_LINE => :endline,
      REQ_PREV_LINE => :prevline, REQ_NEXT_LINE => :nextline,
      REQ_BEG_FIELD => :begfield, REQ_END_FIELD => :endfield,
      REQ_INS_CHAR => :addch, REQ_DEL_CHAR => :delch,
      REQ_DEL_PREV => :delprev, REQ_DEL_WORD => :delword,
      REQ_CLR_EOL => :deleol, REQ_DEL_LINE => :delline,
      REQ_NEW_LINE => :add_new_pgh
    }
    refresh(@data.send(*[@@req_map[req_const], argv].flatten))
  end

  def refresh(mode = :whole)
    return unless mode

    mode = scroll_up if @data.y < 0
    mode = scroll_down if @data.y >= @opt[:height]

    if :whole == mode
      (0..@opt[:height] - 1).each { |i| fresh_screen(i) }
    end

    @opt[:window].move(@data.y, @data.x)
    @opt[:window].refresh
  end

  def scroll_down
    @data.headshift_up(@data.y - @opt[:height] + 1)
    @data.each_line { |l| l.fresh = :whole }
    :whole
  end

  def scroll_up
    @data.headshift_up(@data.y)
    @data.each_line { |l| l.fresh = :whole }
    :whole
  end

  def fresh_screen(i)
    line = @data[i]
    if line
      return unless line.fresh

      lind = line.fresh == :whole ? 0 : (line.info.index[:line] - 1)
      lind = [0, lind].max
      lstr = line.line_str(lind).ljust(@opt[:width] - lind)

      @opt[:window].mvprintw(i, lind, lstr)

      line.fresh = false
    else
      @opt[:window].mvprintw(i, 0, ' ' * @opt[:width])
    end
  end

  def getch
    @opt[:window].move(@data.y, @data.x)
    @opt[:window].getch
  end

  def to_s
    data.head.to_s
  end
end
