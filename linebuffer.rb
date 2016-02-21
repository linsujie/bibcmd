#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'lineinfo'

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

    push_to_next while(@info.size > width)

    pull_from_next while(pullable)

    @need_refresh = false
    @next.refresh_line if @next && @next.need_refresh
  end

  def pullable
    !@info.eop && @next && @info.pre_pull_from(@next.info) <= width
  end

  def push_to_next
    insert_line if @info.eop
    @next ||= LineBuffer.new(@width, '', self, nil)
    @info.push_to(@next.info)

    @next.need_refresh = true
    @next.fresh = :whole
  end

  def pull_from_next
    return unless @next && !@info.eop
    @info.pull_from(@next.info)
    @next.need_refresh = true
    @next.fresh = :whole
    @next.delete_line if @next.info.empty?
  end

  def size
    @previous.size if @previous
    @next ? @next.size + 1 : 1
  end

  def to_s
    @next ? output_str + (@info.eop ? "\n" : ' ') + @next.to_s : output_str
  end

  def strings
    @next ? @next.strings.unshift(@info.to_s) : [@info.to_s]
  end

  def output_str
    @info.words.reject { |w| w.empty? }.join(' ')
  end

  def line_str(x = 0)
    (new_pgraph? ? ' ' * NP_SPACE + @info.to_s : @info.to_s)[x..-1]
  end

  def new_pgraph?
    !@previous || @previous.info.eop
  end

  def x
    @info.index[:line] + (new_pgraph? ? NP_SPACE : 0)
  end

  def insert_line
    new = LineBuffer.new(@width, '', self, @next)

    @next.previous = new if @next
    @next = new
    @next.each_from_cur { |l| l.fresh = :whole }
  end

  def delete_line
    @next.previous = previous if @next
    @previous.next = @next if @previous
    each_from_cur { |l| l.fresh = :whole }
  end

  def join(lb)
    first, second = tail, lb.head
    first.info.eop = true
    first.next, second.previous = second, first
  end

  def each_from_cur
    line = self
    loop do
      break unless line
      yield(line)
      line = line.next
    end
  end

  private

  def width
    new_pgraph? ? @width - NP_SPACE : @width
  end
end


