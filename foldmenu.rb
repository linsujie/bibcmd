#!/usr/bin/env ruby
# encoding:utf-8

require_relative 'menuwrap'
require_relative 'foldlist'

# A foldable Menu
class FoldMenu
  attr_reader :menu
  DFT_OPTION = { list: nil, ccolshift: 0, ancestor: 1, ckey: [10] }

  public

  def initialize(opt)
    @opt = opt
    DFT_OPTION.each_key { |k| @opt[k] = DFT_OPTION[k] unless @opt.key?(k) }

    if !@opt[:panel] && @opt[:default_win]
      @opt[:panel] = Panel::PANEL.new(@opt[:default_win])
    end

    check_input

    @opt[:list] = FoldList.new(@opt[:list], @opt[:ancestor])

    @new_id = @opt[:list].tree.id
    update_menu
  end

  def del
    @mcursor ||= { top_row: 0, current_row: 0 }
    return unless @menu
    @mcursor = @menu.cursor
    @menu.del
  end

  def get
    loop do
      id, out_ch = @menu.get { |current, cmd| yield(current, cmd) }
      break [id, out_ch] unless out_ch == 'z'.ord

      @opt[:panel].show if @opt[:panel]
      ch = @menu.getch
      @opt[:panel].hide if @opt[:panel]
      Panel.update_panels

      fold_menu(ch, id)
    end
  end

  private

  def fold_menu(ch, id)
    return unless %w(m o a).include?(ch.chr)

    @new_id = @opt[:list].send("fold_#{ch.chr}", id)
    update_menu
  end

  def update_menu
    del
    @menu = MenuWrap.new(menu_opt)

    newind = @menu.opt[:choices].index(@new_id)
    if @mcursor[:top_row] <= newind
      @menu.top_row = @mcursor[:top_row]
      (@mcursor[:top_row]..newind - 1).each { @menu.driver(Menu::REQ_DOWN_ITEM) }
    else
      (0..newind - 1).each { @menu.driver(Menu::REQ_DOWN_ITEM) }
    end
  end

  def menu_opt
    mopt = @opt.clone

    mopt[:displays], mopt[:choices] = mopt[:list].to_a
    display_width = mopt[:displays].map(&:size).max + 2
    mopt[:wcolshift] = mopt[:ccolshift] - display_width / 2 if mopt[:ccolshift]

    mopt[:displays] = [mopt[:displays]]

    mopt[:ckey] << 'z'

    mopt
  end

  def check_input
    raise 'FoldList::Please define a list' unless @opt[:list]

    acs_found = @opt[:list].transpose[0].index(@opt[:ancestor])
    raise 'FoldList::ancestor should appear in the input list' unless acs_found
  end
end
