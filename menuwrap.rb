#!/usr/bin/env ruby
# encoding:utf-8

require 'ncursesw'

class Ncurses::Menu::ITEM
  def destroyed?
    @destroyed
  end
end

class Ncurses::Menu::MENU
  def destroyed?
    @destroyed
  end
end

#A wrapper of Ncurses::Menu with extensible key support and multi column
# information support
class MenuWrap
  attr_reader :opt

  include Ncurses::Menu
  include Ncurses

  UNICODE_CHARS = { vline: "\u2502", hline: "\u2500", ltee: "\u251C",
                    rtee: "\u2524",  ttee: "\u252C", dtee: "\u2534",
                    cross: "\u253C" }.map { |k, v| [k, v.encode('utf-8')] }.to_h

  DFT_OPTION = { title: nil, tcolor: nil, colors: nil,
                 width: 20, height: 10, border: nil,
                 flexible: true,
                 choices: [], displays: nil, align: :left,
                 wcolshift: 0, colshift: nil, rowshift: 0,
                 mark: '',
                 qkey: ['q', 27], ukey: ['k', KEY_UP], dkey: ['j', KEY_DOWN],
                 ckey: [10], hkey: [KEY_HOME, 'gg'], ekey: [KEY_END, 'G'],
                 accepted: [], panel: nil, current: 0
  }
  @@default_win = nil

  def initialize(opt)
    @opt = opt
    DFT_OPTION.each_key { |k| @opt[k] = DFT_OPTION[k] unless @opt.key?(k) }
    @opt[:displays] ||= [@opt[:choices]]
    @opt[:colors] ||= @opt[:displays].map { 2 }

    @opt[:border] ||= [ACS_VLINE, ACS_HLINE].map(&:ord)

    %w(qkey ukey dkey ckey hkey ekey accepted).each { |k| format_keymap(k) }

    check_input
    prepare_frame
    ini_menu
  end

  def del
    free_menu(@menus, @items)
    free_window(@window, @subwins)
  end

  def getch
    @window.getch
  end

  def get
    @opt[:panel].show if @opt[:panel]
    draw_border
    @window.refresh

    result = loop do
      ch = @window.getch
      cmd = [@precast, ch]

      break if @opt[:qkey].include?(cmd)
      break [@opt[:choices][current_index], ch] if @opt[:ckey].include?(cmd)

      (@precast = ch) && next if @precast_key.include?(ch) && !@precast

      yield(@opt[:choices][current_index], cmd) if @opt[:accepted].include?(cmd)
      driving(cmd)
      @subwins.each { |subwin| subwin.refresh }

      @precast = nil
    end

    @opt[:panel].hide if @opt[:panel]
    Panel.update_panels

    result
  end

  def cursor
    { top_row: @menus[0].top_row,
      current_row: @items[0].index(@menus[0].current_item) }
  end

  def top_row=(id)
    @menus.each { |menu| menu.top_row = id }
  end

  def driver(action)
    @menus.each { |menu| menu.driver(action) }
  end

  private

  def current_index
    @items[0].index(@menus[0].current_item)
  end

  def read_multi_key(str)
    @precast_key ||= [str[0].ord]
    @precast_key << str[0].ord
    @precast_key.uniq!
    str.split('').map!(&:ord)
  end

  def format_keymap(key)
    rkey =->(k) { k.size == 1 ? [nil, k.ord] : read_multi_key(k) }

    key = key.to_sym
    @opt[key] = @opt[key].map { |k| k.is_a?(Fixnum) ? [nil, k] : rkey.call(k) }
  end

  def driving(ch)
    driver(Menu::REQ_DOWN_ITEM) if @opt[:dkey].include?(ch)
    driver(Menu::REQ_UP_ITEM) if @opt[:ukey].include?(ch)
    driver(Menu::REQ_FIRST_ITEM) if @opt[:hkey].include?(ch)
    driver(Menu::REQ_LAST_ITEM) if @opt[:ekey].include?(ch)
  end

  def ini_menu
    @items = @opt[:displays].map { |l| l.map { |w| ITEM.new(w, '') } }
    @menus = @items.map { |i| MENU.new(i) }

    @menus.zip(@subwins, @opt[:colors])
      .each { |m, w, c| set_menu_format(m, w, c) }
  end

  def set_menu_format(menu, window, color)
    menu.set_menu_win(window)
    menu.set_menu_format(@menu_height, 1)
    menu.set_menu_mark(@opt[:mark])
    menu.fore = Ncurses.color_pair(color) | Ncurses::A_REVERSE
    menu.back = Ncurses.color_pair(color)
    menu.post_menu
  end

  def free_window(window, subwins)
    subwins.each { |w| w.delwin unless w.destroyed? }
    free_main_window(window) unless window.destroyed?
  end

  def free_main_window(window)
    @@default_win ||= WINDOW.new(0, 0, 0, 0)
    @opt[:panel].replace_panel(@@default_win)

    window.delwin
  end

  def free_menu(menus, items)
    menus.each do |menu|
      next if menu.destroyed?

      menu.unpost_menu
      menu.free_menu
    end

    items.each { |ls| ls.each { |i| i.free_item unless i.destroyed? } }
  end

  def check_input
    transposable = @opt[:displays].map { |term| term.size }.uniq.size == 1
    raise 'MenuWrap::Incorrect display content' unless transposable

    color_ok = @opt[:displays].size == @opt[:colors].size
    raise 'MenuWrap::Incorrect color size' unless color_ok
  end

  BORD_HEIGHT = 2
  def prepare_frame
    setwidths
    setheight

    @window = WINDOW.new(@window_height,
                         @opt[:colshift].last + 1,
                         @opt[:rowshift], @opt[:wcolshift])
    @opt[:panel].replace_panel(@window) if @opt[:panel]
    @window.keypad(true)

    gen_subwins
    write_title if @opt[:title]

    draw_border

  end

  def draw_border
    @window.border(@opt[:border][0], @opt[:border][0], @opt[:border][1],
                   @opt[:border][1], ACS_ULCORNER, ACS_URCORNER, ACS_LLCORNER,
                   ACS_LRCORNER)
    return unless @opt[:title]

    hline = @opt[:border][1] == ACS_HLINE ? UNICODE_CHARS[:hline] : @opt[:border][1].chr
    @window.mvprintw(2, 1, hline * (@opt[:colshift][-1] - 1))

    @window.mvprintw(2, 0, UNICODE_CHARS[:ltee])
    @window.mvprintw(2, @opt[:colshift][-1], UNICODE_CHARS[:rtee])

    @opt[:colshift][1..-2].each { |x| draw_split_line(x) }
  end

  def draw_split_line(x)
    @window.mvprintw(@title_height, x, UNICODE_CHARS[:ttee])
    @window.mvprintw(@window_height - 1, x, UNICODE_CHARS[:dtee])

    (@title_height + 1..@window_height - 2)
      .each { |y| @window.mvprintw(y, x, UNICODE_CHARS[:vline]) }
  end

  def write_title
    @titlewin = @window.derwin(1, @opt[:colshift][-1] - 1, 1, 1)
    @titlewin.attron(Ncurses.color_pair(@opt[:tcolor])) if @opt[:tcolor]
    @titlewin.printw(@opt[:title].center(@opt[:colshift][-1] - 1))
  end

  def gen_subwins
    @subwins = @opt[:colshift].each_cons(2).map do |l, r|
      @window.derwin(@menu_height, r - l - 1, @title_height + 1, l + 1)
    end
  end

  def setheight
    flexible_height = [@opt[:height], @opt[:displays][0].size].min
    @menu_height = @opt[:flexible] ? flexible_height : @opt[:height]
    @title_height = @opt[:title] ? 2 : 0

    @window_height = @menu_height + @title_height + BORD_HEIGHT
  end

  def setwidths
    @opt[:colshift] ? constrain_display : read_shifts
  end

  def read_shifts
    @opt[:widths] = @opt[:displays].map { |list| list.map(&:size).max + 1 }
    @opt[:colshift] = @opt[:widths].reduce([0]) { |a, e| a << (e + a[-1]) }
    return unless @opt[:title]

    if @opt[:title].size > @opt[:colshift][-1] - 1
      @opt[:colshift][-1] = @opt[:title].size + 1
      constrain_display
    end
  end

  def constrain_display
    @opt[:widths] = @opt[:colshift].each_cons(2).map { |f, s| s - f }

    cutlist = ->(list, width) { list.map { |term| term[0..width - 1] } }
    @opt[:displays].zip(@opt[:widths]).map! { |l, w| cutlist.call(l, w - 1) }
  end
end
