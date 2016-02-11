#!/bin/env ruby
# encoding: utf-8

require 'ncursesw'

# The blackboard for writing note
class NoteBoard
  attr_reader :panel, :info
  include Ncurses
  include Ncurses::Form

  HEAD_TERM = %w(title author identifier).map(&:to_sym)
  TIPS = ' q: quit   [hjkl], x, dw, dd, $...: same as vim'
  FIELD_EXT_LINE = 50
  STAT_LABEL = { normal: 'NORMAL', insert: 'INSERT' }
  DFT_OPTION = { infocolor: 2,
                 splitor: "\u2500".encode('utf-8'), splitorcolor: 6,
                 width: 80, height: 25, rowshift: 0, colshift: 0,
                 contentcolor: 2, statcolor: 2, statbold: false,
                 tipscolor: 4
  }

  def initialize(opt)
    @opt = opt
    DFT_OPTION.each_key { |k| @opt[k] = DFT_OPTION[k] unless @opt.key?(k) }
    @@padkey_driver_map ||= { KEY_LEFT => REQ_LEFT_CHAR,
                           KEY_RIGHT => REQ_RIGHT_CHAR,
                           KEY_UP => REQ_UP_CHAR,
                           KEY_DOWN => REQ_DOWN_CHAR,
                           KEY_HOME => REQ_BEG_FIELD,
                           KEY_END => REQ_END_FIELD }

    ini_window
  end

  def deal(info)
    @info = info
    prepares
    Ncurses.curs_set(1)

    loop do
      ch = @window.getch
      cmd = [@precast, ch]

      break if 'q'.ord == ch
      :insert == @stat ? insert_deal(ch) : normal_deal(ch)
    end
    get_buffer
  end

  private

  def get_buffer

  end

  def insert_deal(ch)
    set_stat(:normal)
  end

  def normal_deal(ch)
    @@nor_driver_map ||= gen_nor_driver_map

    return set_stat(:insert) if 'i'.ord == ch
    
  end

  def gen_nor_driver_map
    { 'h' => REQ_LEFT_CHAR,
      'l' => REQ_RIGHT_CHAR,
      'k' => REQ_UP_CHAR,
      'j' => REQ_DOWN_CHAR,
      'w' => REQ_NEXT_WORD,
      'b' => REQ_PREV_WORD,
      '00' => REQ_BEG_LINE,
      '$' => REQ_END_LINE,
      'gg' => REQ_BEG_FIELD,
      'G' => REQ_END_FIELD,
      'dd' => REQ_DEL_LINE,
      'dw' => REQ_DEL_WORD,
      'd$' => REQ_DEL_EOL,
      'dG' => REQ_DEL_EOF,
      'x' => REQ_DEL_CHAR,
    }
  end

  def prepares
    write_head
    prepare_form
    prepare_stat
    prepare_tips
    set_stat(:insert)
  end

  def prepare_form
    @field = FIELD.new(@opt[:height] - @headline - 3, @opt[:width] - 2,
                       0, 0, FIELD_EXT_LINE, 0)
    @field.set_field_buffer(0, @info[:item]) if @info[:item]

    @formwin = @window.derwin(@opt[:height] - @headline - 3,
                              @opt[:width] - 2, @headline + 1, 1)
    @formwin.bkgd(Ncurses.color_pair(@opt[:contentcolor]))
    @formwin.keypad(true)

    @form = FORM.new([@field])
    @form.set_form_win(@window)
    @form.set_form_sub(@formwin)

    @form.post_form
  end

  def set_stat(stat)
    @stat = stat
    @status.mvprintw(0, 0, STAT_LABEL[stat])
    @spanel.show
    @tpanel.show if :normal == stat
    Panel.update_panels
    @form.driver(REQ_VALIDATION)
  end

  def prepare_stat
    @status = WINDOW.new(1, @opt[:width] - 2, @opt[:height] - 2, 1)
    @statbold = @opt[:statbold] ? A_BOLD : 0
    @status.bkgd(Ncurses.color_pair(@opt[:statcolor]) | A_REVERSE | @statbold)
    @status.attron(@statbold)
    @status.attron(Ncurses.color_pair(@opt[:statcolor]) | A_REVERSE)

    @status.printw('INSERT')
    @spanel = Panel::PANEL.new(@status)
  end

  def prepare_tips
    tsize = TIPS.size
    ssize = STAT_LABEL.each_value.map(&:size).max
    t_width = [tsize, @opt[:width] - 2 - ssize].min

    @tips = WINDOW.new(1, t_width, @opt[:height] - 2,
                           @opt[:width] - t_width - 1)
    @tips.bkgd(Ncurses.color_pair(@opt[:tipscolor]) | A_REVERSE | @statbold)
    @tips.attron(@statbold)
    @tips.attron(Ncurses.color_pair(@opt[:tipscolor]) | A_REVERSE)
    @tips.printw(TIPS)

    @tpanel = Panel::PANEL.new(@tips)
  end

  def write_head
    @headline = HEAD_TERM.map { |k| line_count("#{k}:#{@info[k]}") }
      .reduce(0, &:+) + 1

    @headwin = @window.derwin(@headline, @opt[:width] - 2, 1, 1)

    @headwin.attron(Ncurses.color_pair(@opt[:infocolor]))
    HEAD_TERM.each { |k| write_item(@headwin, k, @info[k]) }

    @headwin.attron(Ncurses.color_pair(@opt[:splitorcolor]))
    @headwin.attron(A_BOLD)
    @headwin.printw(@opt[:splitor] * (@opt[:width] - 2))
  end

  def write_item(window, key, str)
    window.attron(A_BOLD)
    window.printw("#{key.upcase.class}:")
    window.attroff(A_BOLD)
    window.printw("#{str}\n")
  end

  def line_count(str)
    (str.size.to_f / (@opt[:width] - 2)).ceil
  end

  def ini_window
    @window = WINDOW.new(*%w(height width rowshift colshift)
                         .map { |k| @opt[k.to_sym] })
    @window.box(0, 0)

    @panel = Panel::PANEL.new(@window)
  end

end
