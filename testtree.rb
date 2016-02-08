#!/bin/env ruby
# encoding: utf-8

require_relative 'tree.rb'
require 'test/unit'

class TestTree < Test::Unit::TestCase
  def test_construct
    assert_equal([[0, 1, :a],
                  [1, 3, :c],
                  [2, 2, :d],
                  [2, 4, :b]],
                 list(example_tree))
  end

  def test_sort
    exp = example_tree
    son = exp.find(:word, :c)
    son.sort!(:word)

    assert_equal([[0, 1, :a],
                  [1, 3, :c],
                  [2, 4, :b],
                  [2, 2, :d]],
                 list(exp))
  end

  def test_copy
    a = example_tree

    b = Tree.new([1,:k], %w(id word))
    b << [3, :i] << [4, :f] << [2, :g]

    b.copy(a, :id, :word) # copy the value :word from a to b

    assert_equal([[0, 1, :a],
                  [1, 3, :c],
                  [2, 4, :b],
                  [3, 2, :g]],
                 list(b))
  end

  def test_map
    exp = example_tree
    exp.find(:id, 3).word = :f
    assert_equal(:f, exp.find(:id, 3).word)

    collector = []
    exp.each(:id, :word) { |v| collector << v }
    assert_equal([[1, :a],
                  [3, :f],
                  [2, :d],
                  [4, :b]],
                 collector)

    exp.map!(:id, :word) { |id, word| "#{id} #{word}" }
    assert_equal([[0, '1 a', :a],
                  [1, '3 f', :f],
                  [2, '2 d', :d],
                  [2, '4 b', :b]],
                 list(exp))
  end

  def list(tree)
    tree.to_a { |v, g| [g, v[:id], v[:word]] }
  end

  def example_tree
    example = Tree.new([1,:a], %w(id word))
    cur = example << [3, :c]
    cur << [2, :d]
    cur << [4, :b]

    example
  end

end
