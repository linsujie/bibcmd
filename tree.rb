#!/usr/bin/env ruby
# encoding: utf-8

# A tree
class Tree
  attr_accessor :key, :val, :children

  public

  def initialize(value, key = %w(value))
    @key = key.map(&:to_sym)
    @val = Hash[[@key, value].transpose]
    @children = []

    @key.each { |k| Tree.define_value(k) }
  end

  def <<(value, key = @key)
    subtree = Tree.new(value, key)
    @children << subtree
    subtree
  end

  def find(word, val)
    return self if send(word) == val
    res = @children.each { |child| (c = child.find(word, val)) && (break c) }
    res unless res.is_a?(Array)
  end

  def each(*arr)
    yield(arr.size == 1 ? send(arr[0]) : arr.map { |x| send(x) })
    @children.each { |child| child.each(*arr) { |e| yield e } }
  end

  def map!(word, *app)
    append = ->(w, a) { [*a].unshift(w).map { |k| send(k) } }
    send("#{word}=", yield(app.empty? ? send(word) : append.call(word, app)))
    @children.each { |child| child.map!(word, *app) { |e| yield e } }
  end

  def copy(another, id, val)
    return unless another.is_a?(Tree)

    copytree(another, self, id, val)
  end

  def sort!(word)
    @children.sort_by! { |x| x.send(word) }
    @children.each { |child| child.sort!(word) }
    self
  end

  def to_a(gen = 0)
    recdeal = ->(a, e) { a + e.to_a(gen + 1) { |v, g| yield(v, g) } }
    @children.reduce([yield(@val, gen)]) { |a, e| recdeal.call(a, e) }
  end

  private

  def copytree(ori, tar, id, val)
    return unless tar.val[id] == ori.val[id]

    tar.val[val] = ori.val[val]

    m_tar = getindlist(tar, id)
    m_ori = getindlist(ori, id)

    (m_tar.each_key.to_a & m_ori.each_key.to_a).each do |ind|
      copytree(ori.children[m_ori[ind]], tar.children[m_tar[ind]], id, val)
    end
  end

  def getindlist(tree, id)
    tree.children.each_with_index.map { |s, i| [s.val[id], i] }.to_h
  end

  def self.define_value(key)
    define_method(key) { @val[key.to_sym] }
    define_method("#{key}=") { |v| @val[key.to_sym] = v }
  end
end
