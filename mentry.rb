#!/usr/bin/env ruby
# encoding: utf-8

require 'ncursesw'

# To store the line information in words
class LineInfo
  attr_reader :words, :index
  attr_accessor :size, :focused

  def initialize(string, line_index = 0)
    @words = string.split(/[ ]/)
    @words.push('') if @words.empty?
    @focused = true

    set_line_index(line_index)
    fresh_size
  end

  def addch(ch, index = @index)
    fresh_index(index)

    @size += 1 unless ch == "\n"
    return insert_to_word(ch) unless /\s/ =~ ch
    create_new_word(ch)
  end

  def delch(index = @index)
    fresh_index(index)

    @size -= 1
    return if delete_eol(@index[:word])
    eow? ? join_word : delete_at_word
  end

  def push_to(linfo)
    next_inword = @index[:inword] if last_word? && @focused
    word = @words.pop
    linfo.empty? ? linfo.words[0] = word : linfo.words.unshift(word)

    eol if last_word?

    if next_inword
      linfo.focused, @focused = true, false

      linfo.set_word_index(word: 0, inword: next_inword)
    else
      linfo.index[:word] = linfo.words.size == 1 ? 0 : linfo.index[:word] + 1
      linfo.set_word_index
    end

    return if word == "\n"
    @size -= word.size + 1
    linfo.size += word.size + 1
  end

  def pre_push_to
    @words[-1] == "\n" ? @size : @size - @words[-1].size - 1
  end

  def pre_pull_from(line_info)
    line_info.words[0] == "\n" ? @size : @size + line_info.words[0].size + 1
  end

  def pull_from(linfo)
    inword = linfo.index[:inword] if linfo.first_word? && linfo.focused
    word = linfo.words.shift
    linfo.words.push('') if linfo.words.empty?
    @words.push(word)

    if inword
      @focused, linfo.focused = true, false

      linfo.bol
      set_word_index(word: @words.size - 1, inword: inword)
    else
      linfo.index[:word] -= 1 unless linfo.first_word?
      linfo.set_word_index
    end

    return if word == "\n"
    @size += word.size + 1
    linfo.size -= word.size + 1
  end

  def prevword
    @index[:word] -= 1 unless @index[:word] == 0
    @index[:inword] == 0
    set_word_index
  end

  def nextword
    @index[:word] += 1 unless last_word?
    @index[:inword] == 0
    set_word_index
  end

  def delword
    @words.slice!(@index[:word])
    set_word_index(word: @index[:word], inword: 0)
  end

  def prevch
    return if bol?
    @index[:line] -= 1

    if @index[:inword] == 0
      @index[:word] -= 1
      @index[:inword] = @words[@index[:word]].size
    else
      @index[:inword] -= 1
    end
  end

  def nextch
    return if eol?
    @index[:line] += 1

    if @index[:inword] == @words[@index[:word]].size
      @index[:word] += 1
      @index[:inword] = 0
    else
      @index[:inword] += 1
    end
  end

  def bol
    @index = { word: 0, inword: 0, line: 0 }
  end

  def eol
    set_word_index(word: @words.size - 1, inword: @words[-1].size)
  end

  def last_word?
    @index[:word] >= @words.size - 1
  end

  def first_word?
    @index[:word] <= 0
  end

  def eow?
    @index[:inword] == @words[@index[:word]].size
  end

  def empty?
    @words.size == 1 && @words[0] == ''
  end

  def bol?
    @index[:line] == 0
  end

  def eol?
    last_word? && @index[:inword] == @words[-1].size
  end

  def to_s
    @words.reject { |x| "\n" == x }.join(' ')
  end

  def fresh_size
    @size = to_s.size
  end

  def set_line_index(line_index)
    word, inword, cur = @words.select { |w| w != "\n" }
    .each_with_object([0, 0, 0]) do |w, ind|
      ind[0] += 1
      ind[2] += w.size + 1

      if line_index < ind[2]
        ind[0] -= 1
        ind[1] = line_index - ind[2] + w.size + 1
        break ind[0..1]
      end
    end

    if cur
      word -= 1
      inword = @words[word].size
      line_index = cur - 1
    end

    @index = { word: word, inword: inword, line: line_index }
  end

  def set_word_index(index = @index)
    last_eow(index) if @words[index[:word]] == "\n" && index[:word] > 0

    nw = [@words.size - 1, index[:word]].min
    ninw = [@words[nw].size, index[:inword]].min
    ninw = nw == index[:word] ? ninw : @words[nw].size

    line = @words.map { |w| w.size + 1 }[0, nw].reduce(0, &:+) + ninw
    @index = { word: nw, inword: ninw, line: line }
  end

  private

  def last_eow(index)
    index[:word] -= 1
    index[:inword] = @words[index[:word]].size
  end

  def fresh_index(index)
    if index != @index
      set_line_index(index[:line]) if is_line_index?(index)
      set_word_index(index) if is_word_index?(index)
    end
  end


  def is_word_index?(index)
    !index[:line] && index[:word] && index[:inword]
  end

  def is_line_index?(index)
    index[:line] && !index[:word] && !index[:inword]
  end

  def delete_at_word
    @words[@index[:word]].slice!(@index[:inword])
  end

  def join_word
    return if delete_eol(@index[:word] + 1)

    indrange = @index[:word]..@index[:word] + 1
    @words[indrange] = @words[indrange].join
  end

  def delete_eol(word_index)
    return unless "\n" == @words[word_index]
    @size += 1 # Deleting the eol would not affect the size of a string

    @words.slice!(word_index)
    @index[:inword] = 0
  end

  def insert_to_word(ch)
    if @words[@index[:word]] == "\n"
      @words.insert(@index[:word] + @index[:inword], ch)
      @index[:word] += @index[:inword]
      @index[:inword] = 0
      set_word_index
    end

    @words[@index[:word]].insert(@index[:inword], ch)
    @index[:inword] += 1
    @index[:line] += 1
  end

  def create_new_word(ch)
    @words.insert(@index[:word] + 1, '')

    preword = @words[@index[:word]][0, @index[:inword]]
    afterword = @words[@index[:word]][@index[:inword]..-1]
    @index[:inword] = 0
    @index[:word] += 1
    @index[:line] += 1

    return unless preword && afterword

    if "\n" == ch
      words = [preword, "\n", afterword].reject { |x| x.empty? }
      @words[@index[:word] - 1..@index[:word]] = words
      @index[:word] += words.size - 2
      set_word_index
    else
      @words[@index[:word] - 1..@index[:word]] = [preword, afterword]
    end
  end
end

# A data structrue to store and dealwith paragraph information in lines
class LineBuffer
  attr_reader :width, :info
  attr_accessor :previous, :next, :need_refresh, :fresh

  NP_SPACE = 4

  def initialize(width_, string_ = '', pre = nil, nex = nil)
    @width = width_
    @info = LineInfo.new(string_)
    @fresh = :whole
    @previous, @next = pre, nex
    @need_refresh = !@info.empty?

    refresh_line
  end

  def tail
    @next ? @next.tail : self
  end

  def head
    @previous ? @previous.head : self
  end

  def row
    @previous ? @previous.row + 1 : 0
  end

  def refresh_line(need_refresh = @need_refresh)
    @need_refresh = need_refresh
    return unless @need_refresh
    eol_ind = @info.words.index("\n") || @info.words.size
    n_new_line_words = @info.words.size - 1 - eol_ind
    n_new_line_words.times { push_to_next }

    push_to_next while(@info.size > width)

    loop_pull if @info.words[-1] != "\n"

    @need_refresh = false
    @next.refresh_line if @next && @next.need_refresh
  end

  def loop_pull
    pull_from_next while(@next && @info.pre_pull_from(@next.info) <= width)
  end

  def push_to_next
    insert_line if @info.words[-1] == "\n"
    @next ||= LineBuffer.new(@width, '', self, nil)
    @info.push_to(@next.info)

    @next.need_refresh = true
    @next.fresh = :whole
  end

  def pull_from_next
    return unless @next
    @info.pull_from(@next.info)
    @next.need_refresh = true
    @next.fresh = :whole
    delete_line if @info.words[-1] == "\n" || @next.info.empty?
  end

  def size
    @next ? @next.size + 1 : 1
  end

  def to_s
    @next ? line_str + "\n" + @next.to_s : line_str
  end

  def strings
    @next ? @next.strings.unshift(@info.to_s) : [@info.to_s]
  end

  def line_str(x = 0)
    (new_pgraph? ? ' ' * NP_SPACE + @info.to_s : @info.to_s)[x..-1]
  end

  def new_pgraph?
    !@previous || "\n" == @previous.info.words[-1]
  end

  def x
    @info.index[:line] + (new_pgraph? ? NP_SPACE : 0)
  end

  def insert_line
    new = LineBuffer.new(@width, '', self, @next)

    @next.previous = new if @next
    @next = new
  end

  def delete_line
    @next.next.previous = self if @next.next
    @next = @next.next
  end

  private

  def width
    new_pgraph? ? @width - NP_SPACE : @width
  end
end

# Designed to store the data information of Mentry object
class MentryData
  attr_reader :current

  DFT_OPTION = { width: 50, string: '', headshift: 0 }

  def initialize(opt)
    @opt = opt
    DFT_OPTION.each_key { |k| @opt[k] = DFT_OPTION[k] unless @opt.key?(k) }
    @current = LineBuffer.new(@opt[:width], @opt[:string])
    @current.info.focused = true
    move(0, 0)
  end

  def addch(ch, x = nil)
    file = File.new('templog', 'a')
    @current.info.set_line_index(x) if x

    file.puts "before #{@current.info.words} #{@current.info.index}"
    @current.info.addch(ch)
    file.puts "addch #{@current.info.words} #{@current.info.index}"
    @current.fresh ||= :cursor
    @current.need_refresh = true

    file.close
    update_current
    file = File.new('templog', 'a')
    file.puts "after #{@current.info.words} #{@current.info.index}"
    file.puts ''
    file.close
    :whole
  end

  def delprev(x = nil)
    @current.info.set_line_index(x) if x
    prevchar if @current.info.bol?
    prevchar
    delch
  end

  def delch(x = nil)
    @current.info.set_line_index(x) if x

    @current.pull_from_next if @current.info.eol?
    @current.info.delch
    @current.fresh ||= :cursor
    @current.need_refresh = true

    update_current
    :whole
  end

  def update_current
    (@current.previous || @current).refresh_line(true)
    @current.previous && @current.previous.fresh = :whole if @current.info.bol?
    @current = [@current.previous, @current, @current.next].compact
      .select { |l| l.info.focused }[0]
  end

  def prevchar
    if @current.info.bol?
      return unless prevline
      @current.info.eol
      :cursor
    else
      @current.info.set_line_index(@current.info.index[:line] - 1)
      :cursor
    end
  end

  def nextchar
    if @current.info.eol?
      return unless nextline
      @current.info.bol
      :cursor
    else
      @current.info.set_line_index(@current.info.index[:line] + 1)
      :cursor
    end
  end

  def prevword
    if @current.info.index[:word] == 0
      return unless prevline
      @current.info.set_word_index(word: @current.info.words.size - 1,
                                   inword: 0)
      :cursor
    else
      @current.info.set_word_index(word: @current.info.index[:word] - 1,
                                   inword: 0)
      :cursor
    end
  end

  def nextword
    if @current.info.index[:word] == @current.info.words.size - 1
      return unless nextline
      @current.info.bol
      :cursor
    else
      @current.info.set_word_index(word: @current.info.index[:word] + 1,
                                   inword: 0)
      :cursor
    end
  end

  def begfield
    @current.info.focused = false
    @current = head
    @current.info.focused = true
    @current.info.bol
    :whole
  end

  def endfield
    @current.info.focused = false
    @current = tail
    @current.info.focused = true
    @current.info.eol
    :whole
  end

  def begline
    @current.info.bol
    :cursor
  end

  def endline
    @current.info.eol
    :cursor
  end

  def prevline
    return unless @current.previous
    @current.info.focused = false
    @current.previous.info.focused = true
    @current.previous.info.set_line_index(@current.info.index[:line])
    @current = @current.previous
    :cursor
  end

  def nextline
    return unless @current.next
    @current.info.focused = false
    @current.next.info.focused = true
    @current.next.info.set_line_index(@current.info.index[:line])
    @current = @current.next
    :cursor
  end

  def move(y, x)
    newline = self[y]
    return unless newline
    @current.info.focused = false
    @current = newline
    @current.info.focused = true
    @current.info.set_line_index(x)
    :cursor
  end

  def head
    @current.head
  end

  def tail
    @current.tail
  end

  def [](row)
    line = head
    (row + @opt[:headshift]).times { line = line && line.next }
    line
  end

  def each_line
    line = head
    loop do
      break unless line
      yield(line)
      line = line.next
    end
  end

  def x
    @current.x
  end

  def y
    @current.row - @opt[:headshift]
  end

  def headshift_up(h)
    @opt[:headshift] += h
  end
end

# A multiple line entry
class Mentry
  include Ncurses
  include Ncurses::Form

  attr_reader :data, :panel

  DFT_OPTION = { string: '', headshift: 0,
                 width: 50, height: 23, colshift: 0, rowshift: 0,
                 color: 2, with_border: false
  }

  def initialize(opt)
    @opt = opt
    DFT_OPTION.each_key { |k| @opt[k] = DFT_OPTION[k] unless @opt.key?(k) }

    if @opt[:with_border]
      @opt[:width] -= 2
      @opt[:colshift] += 1
      @opt[:rowshift] += 1
    end

    @data = MentryData.new(opt)
    gen_window
  end

  def driver(req_const, *argv)
    @@req_map ||= {
      REQ_PREV_CHAR => :prevchar, REQ_NEXT_CHAR => :nextchar,
      REQ_PREV_WORD => :prevword, REQ_NEXT_WORD => :nextword,
      REQ_BEG_LINE => :begline, REQ_END_LINE => :endline,
      REQ_PREV_LINE => :prevline, REQ_NEXT_LINE => :nextline,
      REQ_BEG_FIELD => :begfield, REQ_END_FIELD => :endfield,
      REQ_INS_CHAR => :addch, REQ_DEL_CHAR => :delch,
      REQ_DEL_PREV => :delprev
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

    @window.move(@data.y, @data.x)
    @window.refresh
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
    return unless line && line.fresh

    lind = line.fresh == :whole ? 0 : (line.info.index[:line] - 1)
    lind = [0, lind].max

    raise "#{line.info.words} #{line.info.index} #{lind}" unless line.line_str(lind)
    @window.mvprintw(i, lind, line.line_str(lind).ljust(@opt[:width] - lind))

    line.fresh = false
  end

  def free
    @panel.del_panel if @panel
    @frame.delwin if @frame
    @window.delwin if @window
  end

  def getch
    (@frame || @window).getch
  end

  private

  def gen_window
    if @opt[:with_border]
      @frame = WINDOW.new(@opt[:height] + 2, @opt[:width] + 2,
                          @opt[:rowshift] - 1, @opt[:colshift] - 1)
      @window = @frame.derwin(@opt[:height], @opt[:width],
                              @opt[:rowshift], @opt[:colshift])
      @frame.box(0, 0)
      @frame.refresh
      @panel = Panel::PANEL.new(@frame)
    else
      @window = WINDOW.new(@opt[:height], @opt[:width],
                           @opt[:rowshift], @opt[:colshift])
      @panel = Panel::PANEL.new(@window)
    end
  end
end
