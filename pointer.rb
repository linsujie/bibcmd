#!/usr/bin/env ruby
# encoding: utf-8

# Some methods added to Array
class Array
  def swap!(od1, od2)
    self[od1], self[od2] = self[od2], self[od1]
  end

  def swapud!(order, uord)
    od2 = uord == :u ? (order - 1) % size : (order + 1) % size
    swap!(order, od2)
  end
end

# The pointer about where should the note item print, and which is the current
# item
class Pointer
  attr_reader :segment, :location, :len, :pst, :state

  public

  def initialize(array, segsize, state)
    warn = ->() { puts 'Warning:: There is an item too long' }
    warn.call if !array.empty? && segsize < array.max
    @len = array
    @segsize = segsize
    @state = state
    @pst = 0

    repage
  end

  def down
    @pst = (@pst + 1) % @len.size
    @segment[@pst] != @segment[@pst - 1] || @pst == 0
  end

  def up
    @pst = (@pst - 1) % @len.size
    @segment[@pst] != @segment[(@pst + 1) % @len.size] ||
      @pst == @len.size - 1
  end

  def swap(uord)
    @len.swapud!(@pst, uord)
    repage
    move(uord)
  end

  def move(uord)
    uord == :u ? up : down
  end

  def insert(num)
    @len.insert(@pst, num)
    repage
  end

  def delete
    @len.delete_at(@pst)
    @pst = @len.size - 1 if @pst >= @len.size
    repage
  end

  def mod(num, order = @pst)
    @len[order] = num
    repage
  end

  def append(num)
    @len << num
    repage
    @pst = @len.size - 1
  end

  def page(order)
    return if @len.empty?
    (@segment.index(@segment[order])..@segment[0..-1].rindex(@segment[order]))
      .each { |od| yield(od) }
  end

  def chgstat
    @state = @state == :focus ? :picked : :focus
  end

  private

  def repage
    @seg, @cur, @segment, @location = 0, 0, [0], [0]
    @len.each { |num| addnum(num) }
    @segment.pop
    @location.pop
  end

  def addnum(num)
    (@seg, @cur) = @cur + num <= @segsize ? [@seg, @cur + num] : chgpage(num)
    @segment << @seg
    @location << @cur
  end

  def chgpage(num)
    @segment[-1], @location[-1] = @segment[-1] + 1, 0
    [@seg + 1, num]
  end
end
