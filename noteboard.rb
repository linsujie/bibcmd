#!/bin/env ruby
# encoding: utf-8

require 'ncursesw'
require_relative 'driverutils'
require_relative 'menuwrap'
require_relative 'mentry'

# The blackboard for writing note
class NoteBoard
  attr_reader :panel, :info
  include Ncurses
  include Ncurses::Form
  include DriverUtils

  HEAD_TERM = %w(title author identifier).map(&:to_sym)
  TIPS = ' q: quit   [hjkl], x, dw, dd, $...: same as vim'
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
    @padkey_driver_map = { KEY_LEFT => REQ_PREV_CHAR,
                           KEY_RIGHT => REQ_NEXT_CHAR,
                           KEY_UP => REQ_PREV_LINE,
                           KEY_DOWN => REQ_NEXT_LINE,
                           KEY_HOME => REQ_BEG_FIELD,
                           KEY_END => REQ_END_FIELD }
    @nor_driver_map = gen_nor_driver_map
    @ins_driver_map = gen_ins_driver_map

    ini_window
  end

  def deal(info)
    @info = info
    prepares
    Ncurses.curs_set(1)

    loop do
      ch = @mentry.getch
      cmd = [@precast, ch]

      (@precast = ch) && next if @pre_key[@stat].include?(ch) && !@precast

      act_result = :insert == @stat ? insert_deal(cmd) : normal_deal(cmd)
      break if act_result == :quit

      @precast = nil
    end
    Ncurses.curs_set(0)
    @mentry.to_s
  end

  private

  def insert_deal(cmd)
    return set_stat(:normal) if [nil, 27] == cmd

    driver_code = @ins_driver_map[cmd]
    return @mentry.driver(driver_code) if driver_code

    return unless cmd[1] < 256 && cmd[1] >= 0
    return complete if cmd[1].chr == "\t"
    @mentry.driver(REQ_INS_CHAR, cmd[1].chr)
  end

  def complete
    linfo = @mentry.data.current.info
    preword = linfo.words[linfo.index[:word]][0, linfo.index[:inword]]
    menuwords = @mentry.data.dictionary.select { |w| w.start_with?(preword) }
    menuwords -= [preword]
    return if menuwords.empty?
    menu = MenuWrap.new(width: menuwords.map { |w| w.size }.max,
                        height: menuwords.size,
                        wcolshift: @mentry.data.x,
                        rowshift: @mentry.data.y + @headline + 2,
                        choices: menuwords, default_win: @mwin)
    Ncurses.curs_set(0)
    str, cmd = menu.get
    Ncurses.curs_set(1)

    menu.opt[:panel].hide
    menu.del

    return unless str
    preword.size.times { @mentry.driver(REQ_DEL_PREV) }
    (str + ' ').each_char { |ch| @mentry.driver(REQ_INS_CHAR, ch) }
  end

  def normal_deal(cmd)
    return :quit if [nil, 'q'.ord] == cmd
    return set_stat(:insert) if [nil, 'i'.ord] == cmd

    stdscr.mvprintw(0, 100, cmd.to_s)
    stdscr.refresh
    driver_code = @nor_driver_map[cmd]
    @mentry.driver(driver_code) if driver_code
  end

  def gen_ins_driver_map
    { KEY_ENT => REQ_NEW_LINE,
      KEY_BAC1 => REQ_DEL_PREV,
      KEY_BAC2 => REQ_DEL_PREV
    }.merge(@padkey_driver_map)
    .map { |k, v| [format_cmd(k, :insert), v] }.to_h
  end

  def gen_nor_driver_map
    { 'h' => REQ_PREV_CHAR,
      'l' => REQ_NEXT_CHAR,
      'k' => REQ_PREV_LINE,
      'j' => REQ_NEXT_LINE,
      'w' => REQ_NEXT_WORD,
      'b' => REQ_PREV_WORD,
      '00' => REQ_BEG_LINE,
      '$' => REQ_END_LINE,
      'gg' => REQ_BEG_FIELD,
      'G' => REQ_END_FIELD,
      'dd' => REQ_DEL_LINE,
      'dw' => REQ_DEL_WORD,
      'd$' => REQ_CLR_EOL,
      'x' => REQ_DEL_CHAR,
      KEY_ENT => REQ_NEXT_LINE,
      KEY_BAC1 => REQ_PREV_CHAR,
      KEY_BAC2 => REQ_PREV_CHAR,
    }.merge(@padkey_driver_map).map { |k, v| [format_cmd(k), v] }.to_h
  end

  def prepares
    write_head
    prepare_mentry
    prepare_stat
    prepare_tips
    set_stat(:insert)
  end

  def prepare_mentry
    @mwin = @window.derwin(@opt[:height] - @headline - 3,
                           @opt[:width] - 2, @headline + 1, 1)
    @mwin.bkgd(Ncurses.color_pair(@opt[:contentcolor]))
    @mwin.attron(Ncurses.color_pair(@opt[:contentcolor]))
    @mwin.keypad(true)
    @mentry = Mentry.new(string: @info[:item], window: @mwin)
    @mentry.driver(REQ_END_FIELD)
    @mpanel = Panel::PANEL.new(@mwin)
  end

  def set_stat(stat)
    @stat = stat
    @status.mvprintw(0, 0, STAT_LABEL[stat])
    @spanel.show
    @tpanel.show if :normal == stat
    Panel.update_panels
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
    @window.keypad(true)
    @window.box(0, 0)

    @panel = Panel::PANEL.new(@window)
  end

end
