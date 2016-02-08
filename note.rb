#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'message.rb'
require_relative 'insert.rb'
require_relative 'pointer.rb'
require 'curses'

include Curses

# The notes with position information
class Note
  include Message

  attr_reader :notes, :items, :ptr, :changed

  public

  def initialize(opt)
    @opt = opt
    @notes = opt[:note]
    @changed = false
    @items = notes.split("\n\n").map { |item| dealitem(item) }
    @ptr = Pointer.new(@items.reduce([]) { |a, e| a << e.flatten.size + 2 },
                       @opt[:nheight], :focus)
  end

  def item(order = @ptr.pst)
    @items[order].map { |line| line.join(' ') }.join("\n")
  end

  [:swap, :mod, :append, :insert, :delete].each do |action|
    define_method(action) do |item = ''|
      @changed = true
      send("#{action}_core", item)
    end
  end

  def store
    @changed = false
    @notes = (0..@items.size - 1)
             .reduce([]) { |a, e| a << item(e) }.join("\n\n")
  end

  private

  def delete_core(_)
    @items.delete_at(@ptr.pst)
    @ptr.delete
  end

  def append_core(item)
    @items << dealitem(item)
    @ptr.append(@items.last.flatten.size + 2)
  end

  def insert_core(item)
    @items.insert(@ptr.pst, dealitem(item))
    @ptr.insert(@items[@ptr.pst].flatten.size + 2)
  end

  def mod_core(item)
    @items[@ptr.pst] = dealitem(item)
    @ptr.mod(@items[@ptr.pst].flatten.size + 2)
  end

  def swap_core(uord)
    @items.swapud!(@ptr.pst, uord)
    @ptr.swap(uord)
  end

  def cutline(line, width)
    chgl = ->(a, wd, wth) { a.empty? ? true : a[-1].size + wd.size >= wth }

    line.split(' ').each_with_object([]) do |word, page|
      chgl.call(page, word, width) ? page << word : page[-1] << " #{word}"
    end
  end

  def dealitem(item)
    item.sub(/\A\s*/, '@@').split("\n").select { |ln| ln != '' }
      .map { |ln| cutline(ln, @opt[:width]).map { |l| l.sub('@@', '   ') } }
  end
end

# The normal mode
module NoteItfBase
  include Message
  attr_reader :opt, :note

  public

  def change_item(with_cont = false, act = :insert)
    curs_set(1)

    ins = insmode(with_cont ? @note.item : '')

    ins.deal
    @note.send(act, ins.file.string)

    curs_set(0)
    pagerefresh
  end

  def insmode(string)
    Insmode.new(string, @opt[:height],
                [@opt[:scheight] - @opt[:height] - 1, @opt[:scwidth]])
  end

  [[:insert, false], [:append, false], [:mod, true]].each do |func, cont|
    define_method(func) { send(:change_item, cont, func) }
  end

  def picknote
    @note.ptr.chgstat
    show_note(@note.ptr.pst)
  end

  def move(uord)
    curbf = @note.ptr.pst
    fr = @note.ptr.state == :picked ? @note.swap(uord) : @note.ptr.move(uord)

    show_note(curbf, false)
    show_note

    pagerefresh if fr
  end

  def store
    @note.store if asks(:store)
  end

  def delete
    @note.delete && pagerefresh if asks(:delete)
  end

  private

  QUITSTC = 'The note has not been saved yet, do you want to quit?'

  def pagerefresh
    clearpage
    @note.ptr.page(@note.ptr.pst) { |ind| show_note(ind, false) }
    show_note
  end

  def clearpage
    win = Window.new(@opt[:scheight], @opt[:scwidth], @opt[:height], 0)
    win.refresh
    win.close
  end

  def show_note(order = @note.ptr.pst, state = @note.ptr.state)
    return if @note.items.empty?

    content = getnotewin(order, state)
    showcontent(content, order, state)

    content.refresh
  end

  def showcontent(content, order, state)
    content.framewin.attrset(A_BOLD) if state
    content.framewin.attron(color_pair(COLORS[:note_frame]))
    content.cont.attron(color_pair(COLORS[:note_content]))
    content.cont.addstr(@note.items[order].join("\n"))
  end

  def getnotewin(order, state)
    hegt, alti = getnoteposi(order)
    frame = state == :picked ? %w(! ~) : %w(| -)

    Framewin.new(hegt - 2, @opt[:width], alti, @opt[:labspace], frame)
  end

  def getnoteposi(order)
    [@note.ptr.len[order], @note.ptr.location[order] + @opt[:height]]
  end
end

# The interface of note
class NoteItf
  include NoteItfBase

  public

  DEFOPT = { note: '', title: '', author: '', identifier: '', scheight: 20,
             scwidth: 100, labspace: 2 }
  def initialize(opt = DEFOPT)
    @opt = opt
    DEFOPT.each_key { |k| @opt[k] = DEFOPT[k] unless @opt.key?(k) }

    @opt[:author] = Author.short(@opt[:author])
    formatopt

    @note = Note.new(@opt)
  end

  def deal
    pagerefresh

    loop do
      char = showmessage('').getch
      dealchar(char)
      yield(char) if block_given?
      break if char == 'q' && (@note.changed ? asks(:quit) : true)
    end
  end

  private

  def formatopt
    @opt[:width] = @opt[:scwidth] - 2 - 2 * @opt[:labspace]
    @opt[:height] = showhead
    @opt[:nheight] = @opt[:scheight] - @opt[:height] - 1
  end

  def addstring(string, pair = -1, bold = false)
    attrset(A_BOLD) if bold
    attron(color_pair(pair))

    addstr(string)

    attroff(A_BOLD) if bold
    attroff(color_pair(pair))
  end

  def showline(key, content)
    addstring("#{key}: ", COLORS[:note_key], true)
    addstring("#{content}\n", COLORS[:note_key])
    "#{key}: #{content}\n"
  end

  def showhead
    setpos(0, 0)
    headstr = %w(title author identifier).map(&:to_sym)
              .reduce('') { |a, e| a + showline(e.upcase, @opt[e]) }
    addstring('^' * cols, COLORS[:note_splitor], true)
    refresh

    countline(headstr)
  end

  def countline(headstr)
    opt = { note: headstr, nheight: lines }
    Note.new(@opt.merge(opt)).items.flatten.size + 1
  end

  STRONG_COMMAND = %w(a i r s)
  COMMANDS = { # bind methods to the keys
    s: :store,
    a: :append,
    i: :insert,
    m: :mod,
    d: :delete,
    p: :picknote,
    r: :pagerefresh,
    :'10' => [:move, :d],
    :'9' => [:move, :d],
    j: [:move, :d],
    k: [:move, :u]
  }

  def dealchar(char)
    return if @note.items.empty? && !STRONG_COMMAND.include?(char)

    cmd = COMMANDS[char.to_s.to_sym] || return
    cmd.is_a?(Array) ? send(cmd[0], cmd[1]) : send(cmd)
  end
end
