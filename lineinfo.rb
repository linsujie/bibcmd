#!/usr/bin/env ruby
# encoding: utf-8

# To store the line information in words
class LineInfo
  attr_reader :words, :index
  attr_accessor :size, :focused, :eop

  def initialize(string, line_index = 0)
    init(string, line_index)

    @focused = false
    @eop = false
  end

  def init(string, line_index = 0)
    @words = string.split
    @words.push('') if @words.empty?
    set_line_index(line_index)
    fresh_size
  end

  def delword
    wind, inwind = @index[:word], @index[:inword]
    word, nextword = @words[wind], @words[wind + 1]

    @size -= word.size + 1 - inwind
    @words[wind..wind + 1] = [word[0, inwind], nextword].join
  end

  def addch(ch, index = @index)
    fresh_index(index)

    @size += 1
    return insert_to_word(ch) unless ' ' == ch
    create_new_word
  end

  def delch(index = @index)
    fresh_index(index)

    @size -= 1
    eow? ? join_word : delete_at_word
  end

  EOP_PUSH_ERR = 'LineInfo:: an end of paragraph could not be pushed to an exist line'
  def push_to(linfo)
    push_eop(linfo) if @eop

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

    @size -= word.size + 1
    linfo.size += word.size + 1
  end

  def push_eop(linfo)
    raise EOP_PUSH_ERR unless linfo.empty?
    linfo.eop = true
    @eop = false
  end

  def pre_push_to
    @size - @words[-1].size - 1
  end

  def pre_pull_from(line_info)
    @size + line_info.words[0].size + 1
  end

  EOP_PULL_ERR = 'LineInfo:: Nothing could be pulled after the end of paragraph'
  def pull_from(linfo)
    raise EOP_PULL_ERR if @eop

    inword = linfo.index[:inword] if linfo.first_word? && linfo.focused

    word = linfo.words.shift
    if linfo.words.empty?
      linfo.words.push('')
      @eop, linfo.eop = true, false if linfo.eop
    end
    @words.push(word)

    if inword
      @focused, linfo.focused = true, false

      linfo.bol
      set_word_index(word: @words.size - 1, inword: inword)
    else
      linfo.index[:word] -= 1 unless linfo.first_word?
      linfo.set_word_index
    end

    @size += word.size + 1
    linfo.size -= word.size + 1
  end

  def prevword
    @index[:word] -= 1 unless first_word?
    @index[:inword] == 0
    set_word_index
  end

  def nextword
    @index[:word] += 1 unless last_word?
    @index[:inword] == 0
    set_word_index
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
    @words.join(' ')
  end

  def fresh_size
    @size = to_s.size
  end

  def set_line_index(line_index)
    word, inword, cur = @words.each_with_object([0, 0, 0]) do |w, ind|
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
    nw = [@words.size - 1, index[:word]].min
    ninw = [@words[nw].size, index[:inword]].min
    ninw = nw == index[:word] ? ninw : @words[nw].size

    line = @words.map { |w| w.size + 1 }[0, nw].reduce(0, &:+) + ninw
    @index = { word: nw, inword: ninw, line: line }
  end

  private

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
    indrange = @index[:word]..@index[:word] + 1
    @words[indrange] = @words[indrange].join
  end


  def insert_to_word(ch)
    @words[@index[:word]].insert(@index[:inword], ch)
    @index[:inword] += 1
    @index[:line] += 1
  end

  def create_new_word
    @words.insert(@index[:word] + 1, '')

    preword = @words[@index[:word]][0, @index[:inword]]
    afterword = @words[@index[:word]][@index[:inword]..-1] || ''
    @words[@index[:word]..@index[:word] + 1] = [preword, afterword]

    @index[:inword] = 0
    @index[:word] += 1
    @index[:line] += 1
  end
end


