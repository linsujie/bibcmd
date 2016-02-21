#!/usr/bin/env ruby
# encoding: utf-8

require 'set'
require_relative 'linebuffer'

# Designed to store the data information of Mentry object
class MentryData
  attr_reader :current

  DFT_OPTION = { width: 50, string: '', headshift: 0 }

  def initialize(opt)
    @opt = opt
    DFT_OPTION.each_key { |k| @opt[k] = DFT_OPTION[k] unless @opt.key?(k) }
    paragraphs = @opt[:string].split("\n")
    paragraphs.push('') if paragraphs.empty?
    paragraphs.each do |pgh|
      newlb = LineBuffer.new(@opt[:width], pgh)
      @current ? @current.join(newlb) : @current = newlb
    end

    @current.info.focused = true
    move(0, 0)
  end

  def addch(ch, x = nil)
    @current.info.set_line_index(x) if x

    return add_new_pgh if ch == "\n"

    @current.info.addch(ch)
    @current.fresh ||= :cursor
    @current.need_refresh = true

    update_current
    :whole
  end

  def add_new_pgh
    lind = @current.info.index[:line]
    pline, nline = @current.info.to_s.insert(lind, "\n").split("\n")

    thiseop, @current.info.eop = @current.info.eop, true

    if nline
      @current.info.init(pline, lind)
      @current.insert_line
      @current.next.info.init(nline)
      @current.next.info.eop = thiseop
    end

    @current.insert_line unless @current.next
    nextline(0)

    @current.fresh ||= :cursor
    @current.need_refresh = true
    update_current
    :whole
  end

  def delword(x = nil)
    @current.info.set_line_index(x) if x
    return delch if @current.info.eow?

    @current.info.delword

    @current.fresh ||= :cursor
    @current.need_refresh = true
    update_current
    :whole
  end

  def delline
    @current.delete_line
    @current.info.init('', 0) if !@current.previous && !@current.next

    @current = @current.next || @current.previous || @current
    @current.info.focused = true
    :whole
  end

  def deleol
    add_new_pgh
    @current.previous.fresh ||= :cursor
    @current.previous.need_refresh = true

    delline while(!@current.info.eop && @current.next)

    last_line = !@current.next
    delline
    @current = @current.previous unless last_line
    @current.info.focused = true
    update_current
    :whole
  end

  def delprev(x = nil)
    @current.info.set_line_index(x) if x
    prevchar
    delch
  end

  def delch(x = nil)
    @current.info.set_line_index(x) if x

    if @current.info.eop && @current.info.eol?
      @current.info.eop = false
      @current.next.fresh = :whole if @current.next
      @current.next.need_refresh = true if @current.next
    else
      @current.pull_from_next if @current.info.eol?
      @current.info.delch
    end

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

  def nextline(lind = nil)
    return unless @current.next
    @current.info.focused = false
    @current.next.info.focused = true
    @current.next.info.set_line_index(lind || @current.info.index[:line])
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
    head.each_from_cur { |l| yield(l) }
  end

  def x
    @current.x
  end

  def y
    @current.row - @opt[:headshift]
  end

  def dictionary
    dict = Set.new
    each_line { |l| dict += l.info.words }
    dict
  end

  def headshift_up(h)
    @opt[:headshift] += h
  end
end


