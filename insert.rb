#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'menu.rb'

require 'curses'
include Curses

# To store a string in the format with position information of each character
class TxtFile
  attr_reader :curse, :array, :position

  public

  def initialize(string, maxcols)
    @array = string.each_char.to_a << :end
    @maxcols = maxcols
    @position = []
    @curse = @array.size - 1
    getposition(0)
  end

  def string
    @array[0..-2].join('')
  end

  def each(bgn = 0)
    (bgn..@array.size - 2)
      .each { |ind| yield(letter(ind), x(ind), y(ind)) }
  end

  def letter(curse = @curse)
    @array[curse] == "\n" ? '' : @array[curse]
  end

  def x(curse = @curse)
    @position[curse][1] < 0 ? @position[curse - 1][1] + 1 : @position[curse][1]
  end

  def y(curse = @curse)
    @position[curse][1] < 0 ? @position[curse - 1][0] : @position[curse][0]
  end

  def addlt(letter)
    @array.insert(@curse, letter)
    getposition(@curse)
    @curse += 1
  end

  def dellt
    return if @array.size == 1
    @array.delete_at(@curse)
    @curse %= @array.size
    getposition(@curse)
  end

  def move(direct)
    valhash = { l: (@curse - 1) % @array.size, r: (@curse + 1) % @array.size,
                e: @array.size - 1, h: 0 }
    case direct
    when :u then getupline
    when :d then getdownline
    else @curse = valhash[direct]
    end
  end

  private

  def getdownline
    (line, cols) = @position[@curse]
    maxline = @position.transpose[0].max
    @curse = line == maxline ? @curse : getcurse(line + 1, cols)
  end

  def getupline
    (line, cols) = @position[@curse]
    @curse = line == 0 ? @curse : getcurse(line - 1, cols)
  end

  def getcurse(line, cols)
    @position.index([line, cols]) || getcurse(line, cols < 0 ? 0 : cols - 1)
  end

  def getposition(bgn)
    @position.pop(@position.size - bgn)
    @array[bgn..-1].reduce(@position) { |a, e| a << nextpos(a, e) }
  end

  def nextpos(pos, letter)
    return [0, 0] if pos.empty?
    addpos = ->(la) { la[1] == @maxcols ? [la[0] + 1, 0] : [la[0], la[1] + 1] }
    letter == "\n" ? [pos.last[0] + 1, -1] : addpos.call(pos.last)
  end
end

# The basic methods for insert mode
module InsmodeBase
  attr_reader :file
  attr_writer :complist

  public

  def reset(string = '')
    @file = TxtFile.new(string, @winsize[1] - 1)
  end

  private

  MVHASH = { KEY_LEFT => :l, KEY_RIGHT => :r, KEY_UP => :u, KEY_DOWN => :d,
             KEY_HOME => :h, KEY_END => :e }
  KEY_DELETE = [127, 263]

  def prefixdeal
    showstr(0) && showch
    @tabfocus = false
  end

  def normchar?(char)
    char.is_a?(String) && !@tabfocus
  end

  def delch
    @file.move(:l)
    @file.dellt
    winrefresh
  end

  def winrefresh
    @window.cont.clear
    showstr(0)
  end

  def addch(ch)
    @file.addlt(ch)
    ch == "\n" ? winrefresh : showstr(@file.curse - 1)
  end

  def move(direct)
    @file.move(direct)
    showch
    @window.cont.refresh
  end

  def showch(letter = @file.letter, x = @file.x, y = @file.y)
    @window.cont.setpos(y, x)
    return if (letter == :end) || (letter == '')
    @window.cont.addch(letter)
    @window.cont.setpos(y, x)
  end

  def showstr(bgn = @file.curse)
    @file.each(bgn) { |letter, x, y| showch(letter, x, y) }
    @window.refresh([@file.y, @file.x - 1])
    @window.cont.setpos(@file.y, @file.x)
  end
end

# The insert mode
class Insmode
  include InsmodeBase

  public

  def initialize(string, position, winsize, mode = :ml, frame = false)
    @file = TxtFile.new(string, winsize[1] - 1)
    @mode = mode
    @winsize = winsize
    @lsft, @csft = [*position] << 0

    @window = Framewin.new(@winsize[0], @winsize[1], @lsft, @csft, frame)
    @window.cont.keypad(true)

    @quitkey = 10
    @chgst = 9
    @complist = false
    @chgline = mode == :ml ? 10 : -1
  end

  def deal
    prefixdeal

    contrl = ->(ch) { block_given? ? control(ch) { yield } : control(ch) }
    loop do
      curs_set(1)
      ch = @window.cont.getch
      break if :quit == (normchar?(ch) ? addch(ch) : contrl.call(ch))
    end
    curs_set(0)

    yield if block_given?
  end

  private

  def complete
    @tabfocus = false
    menulist, tocmp = compmenu
    return if menulist.nil? || menulist.empty?
    lsft = @mode == :ml ? @lsft + 1 : @lsft + 2
    word = Menu.new([menulist],
                    yshift: lsft, xshift: [@csft + @file.x], length: 10,
                    fixlen: nil, width: nil, mainmenu: 0, frame: %w(| -))
           .get.sub(tocmp, '')

    word.each_char { |l| @file.addlt(l) }
    yield if block_given?
    winrefresh
  end

  def compmenu
    case @complist
    when :file then obtfilelist
    when false then autocomp
    else [compsele(@complist, @file.string), @file.string]
    end
  end

  def autocomp
    tmplist = @file.string.split(' ')
    [compsele(tmplist[0..-2], tmplist[-1]), tmplist[-1]]
  end

  def obtfilelist
    return unless %r((?<base>.+/)?(?<tocmp>[^/]{0,})) =~ './' + @file.string
    return unless File.directory?(base)
    distgs = ->(x) { File.file?("./#{base}#{x}") ? x : x + '/' }
    [compsele(Dir.foreach(base).to_a, tocmp).map { |x| distgs.call(x) }, tocmp]
  end

  def compsele(list, str)
    list.uniq.select { |item| item.start_with?(str) }
  end

  def control(ch)
    focus = ->(char) { block_given? ? focused(char) { yield } : focused(char) }
    @tabfocus ? focus.call(ch) : unfocused(ch)
  end

  def unfocused(ch)
    return move(MVHASH[ch]) if MVHASH.key?(ch)

    delch if KEY_DELETE.include?(ch)
    case ch
    when @chgline then addch("\n")
    when @chgst then @tabfocus = true
    end
  end

  def focused(ch)
    case ch
    when @quitkey then :quit
    else block_given? ? complete { yield } : complete
    end
  end
end
