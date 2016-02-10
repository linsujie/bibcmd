#!/usr/bin/env ruby
# encoding: utf-8

require 'ncursesw'
require_relative 'frame.rb'
require_relative 'foldlist.rb'

# The basic utils for menu
module MenuUtils
  include Ncurses
  attr_reader :curse, :scurse, :list

  public

  def setctrl(qkey, dkey, ukey)
    @qkey = qkey
    @dkey = dkey
    @ukey = ukey
  end

  def set(curse, scurse, list = @list)
    @list = list[0].is_a?(Array) ? list : [list]
    @curse = curse
    @scurse = scurse

    mrefresh
  end

  def setcol(visible, mainm = @opts[:mainmenu])
    @visible = visible
    @opts[:mainmenu] = mainm
  end

  def current(col = @opts[:mainmenu])
    @list[col] ? @list[col][@curse % listsize].to_s : nil
  end

  private

  def pitem(col, ind)
    pointstr(col, @list[col][ind % listsize].to_s, ind - @scurse)
  end

  def colrefresh(col)
    @win[col].freshframe
    (@scurse..@scurse + @contlen - 1).each { |ind| pitem(col, ind) }

    #@win[col].cont.refresh
    frefresh(col)
  end

  def pointstr(col, strs, line)
    pair = @visible[col]
    @win[col].cont.attron(color_pair(pair)) if pair != true
    @win[col].cont.setpos(line, 0)
    @win[col].cont.addstr(fillstr(strs, col))
    @win[col].cont.attroff(color_pair(pair)) if pair != true
  end

  def theta(x)
    x > 0 ? x : 0
  end

  def fillstr(str, col = @opts[:mainmenu])
    str + ' ' * theta(@width[col] - str.size)
  end

  def frefresh(col)
    @win[col].cont.attron(A_STANDOUT)
    pointstr(col, current(col), @curse - @scurse)
    @win[col].cont.attroff(A_STANDOUT)
    @win[col].refresh
  end

  def listsize
    @list[0].size == 0 ? 1 : @list[0].size
  end

  def cursedown(process = nil)
    return (@curse, @scurse = 0, 0) if @curse == @list[0].size - 1

    @curse += 1
    @scurse += 1 if @scurse == @curse - @maxlen
    process.call if process
  end

  def curseup(process = nil)
    lsize = @list[0].size
    return (@curse, @scurse = lsize - 1, lsize - @contlen) if @curse == 0

    @curse -= 1
    @scurse -= 1 if @scurse == @curse + 1
    process.call if process
  end
end

# Creating a menu
class Menu
  include MenuUtils
  attr_reader :win, :curse, :scurse

  public

  DEFAULTOPT = { yshift: 0, xshift: [0], length: 20, fixlen: true, width: nil,
                 mainmenu: 0, frame: %w(| -) }
  def initialize(list, opts = DEFAULTOPT)
    @opts = opts
    @list = list
    DEFAULTOPT.each_key { |k| @opts[k] = DEFAULTOPT[k] unless @opts.key?(k) }

    construct

    @qkey = ['q', ' ', 10]
    @dkey = ['j', KEY_DOWN, 9]
    @ukey = ['k', KEY_UP]
  end

  def construct(xshift = 0)
    @opts[:xshift].map! { |x| x + xshift }
    ininumbers

    @win = (0..@opts[:xshift].size - 1).reduce([]) do |a, e|
      a << Framewin.new(@maxlen, @width[e], @opts[:yshift],
                        @opts[:xshift][e], @opts[:frame])
    end

    @win.each { |win| win.cont.keypad(true) }
  end

  def get(process = nil)
    curs_set(0)

    loop do
      mrefresh
      char = getch
      deal(char, process)
      break if @qkey.include?(char)
    end
    current
  end

  def mrefresh(xshift = 0)
    construct(xshift)
    @visible
      .each_with_index { |bool, ind| colrefresh(ind) if bool && @list[ind] }

    #@win[@opts[:mainmenu]].cont
  end

  def to_a(col = @opts[:mainmenu])
    @list[col]
  end

  private

  def ininumbers
    @contlen = [@list[0].size, @opts[:length]].min
    @maxlen = @opts[:fixlen] ? @opts[:length] : @contlen

    @curse ||= 0
    @scurse ||= 0
    @visible ||= @opts[:xshift].map { true }

    lastw = @opts[:width] || @list[0].map(&:size).max + 3
    @width = @opts[:xshift].each_cons(2)
             .map { |pvs, nxt| nxt - pvs - 1 } << lastw
  end

  def deal(char, process = nil)
    return if @list[0].empty?

    cursedown(process) if @dkey.include?(char)
    curseup(process) if @ukey.include?(char)
  end
end

# The advance menu that support extra dealing
class AdvMenu < Menu
  attr_reader :char
  attr_accessor :curse, :scurse

  def get(ind = @opts[:mainmenu], process = nil)
    curs_set(0)

    loop do
      mrefresh
      @char = getch
      deal(@char, process)
      yield(self, @char.to_s) if block_given?
      break if @qkey.include?(@char)
    end
    current(ind)
  end
end

# The menu that able to be folded
class FoldMenu < AdvMenu
  attr_reader :fdlist

  public

  def initialize(fdlist, opts = DEFAULTOPT)
    @fdlist = fdlist
    super(fdlist.to_a, opts)
  end

  def get(ind = @opts[:mainmenu], process = nil)
    curs_set(0)

    @state = :normal
    loop do
      mrefresh
      @char = getch
      deal(@char, process)
      fold if @char == 'z'

      break if @state == :normal && @qkey.include?(@char)
      @state = yield(@fdlist, @state, @char.to_s.to_sym) if block_given?
    end
    current(ind)
  end

  def set(fdlist = @fdlist)
    fdlist.tree.copy(@fdlist.tree, :id, :ostate)
    @fdlist = fdlist
    @list = fdlist.to_a

    mrefresh
  end

  private

  FOLD_FUNC = { m: :fold_m, a: :fold_a, o: :fold_o }

  def fold
    char = @win[0].cont.getch.to_sym
    @fdlist.send(FOLD_FUNC[char], current(1).to_i) if FOLD_FUNC[char]
    @list = @fdlist.to_a

    ininumbers
    @curse = @curse % @list[0].size
    @scurse = @curse - @maxlen + 1 if @scurse < @curse - @maxlen + 1
    @scurse = @curse if @scurse > @curse
  end
end
