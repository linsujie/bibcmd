#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'tree.rb'

# A list that could be folded, it's initialized by a list in which each of the
# items contain [self_id, parent_id, content...]
class FoldList
  attr_accessor :tree

  public

  def initialize(list, ancestor)
    list = list.map { |item| [item[0], item[1], false, false] + item[2..-1] }
    @tree = Tree.new(list.find { |x| x[0] == ancestor },
                     %w(id parent ostate tstate keyname))
    insert_children(@tree, list)
    @tree.ostate = true
    @tree.sort!(:keyname)
  end

  def fold_m(id = 0)
    @tree.map!(:ostate) { false }
  end

  def fold_o(id = 0)
    @tree.map!(:ostate) { true }
  end

  def fold_a(id)
    object = @tree.find(:id, id)
    object = @tree.find(:id, object.parent) if object.children.empty?
    object.ostate = !object.ostate
  end

  def to_a
    @list = []
    show(@tree)
    @list.transpose
  end

  def to_list
    @tree.to_a { |v, g| [v[:id], v[:parent], v[:keyname]] }
  end

  def size
    to_a[0].map(&:size).max + 3
  end

  def tag(vals, cols = :id)
    obj = @tree.find(cols, vals)
    obj.tstate = !obj.tstate
  end

  private

  OLABEL = { true => '- ', false => '+ ' }
  def show(obj, gen = 0)
    return if obj.ostate == nil
    label = obj.children.empty? ? '  ' : OLABEL[obj.ostate]
    label += obj.tstate ? '*' : ' '
    @list << [ label + '  ' * gen + obj.keyname, obj.id]
    obj.children.each { |child| show(child, gen + 1) } if obj.ostate
  end

  def insert_children(node, list)
    actlist = list.select { |term| term[1] == node.id }
    actlist.each { |term| node << term }
    node.children.each { |son| insert_children(son, list - actlist) }
  end
end
