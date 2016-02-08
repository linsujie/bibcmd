#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'note.rb'
require_relative 'content.rb'

# The utils for cmdbib, including the logic for all the substantial
# multipulations
CmdBibBase = Struct.new(:bib) do
  TMPFILE = File.expand_path('~/Documents/tmp.bib')

  private

  def search(word)
    return [] if word == ''
    bib.search(word.split(' '))
    .map { |item| [item[0], bib.keynames(item[1]), item[6], item[1]] }
    .transpose
  end

  def listidents(idents)
    kind = idents.map { 'identifier' }
    bib.db.selects(:bibref, %w(identifier id title), kind, idents)
    .map { |item| [item[0], bib.keynames(item[1]), item[2], item[1]] }
    .transpose
  end

  def obtainlist(list)
    list.map { |x| bib.db.select(:bibref, %w(identifier id title), :id, x) }
    .select { |x| x[0] }
    .map { |it, _| [it[0], bib.keynames(it[1]), it[2], it[1]] }.transpose
  end

  def keyidents(keyid)
    obtainlist(bib.db.select(:bibreflink, :ref_id, :key_id, keyid).flatten)
  end

  def listrefresh
    @list.set(@list.curse, @list.scurse, obtainlist(@list.to_a(3)))
  end

  def update_item(bibname)
    bib.modbib(@list.current(-1), bibname)
    back_bibfile(bibname)

    refreshpanel
  end

  def diag_with_msg(comp_type, msg_type)
    showmessage(Message::INDCSTC[msg_type])
    result = listdiag(comp_type, Message::INDCSTC[msg_type])
    showmessage('')
    result
  end

  def back_bibfile(bibname)
    bibname = File.expand_path(bibname)
    FileUtils.mv(bibname, @backup_bib) unless bibname == @backup_bib
  end

  def listdiag(comps = false, bgstrs = '')
    @diag.reset
    @diag.complist = comps

    @diag.deal do
      refreshpanel(false)
      showmessage(bgstrs)
    end

    yed = ->(str) { str == '' ? str : yield(str) }
    block_given? ? yed.call(@diag.file.string) : @diag.file.string
  end

  KEY_STATE_MAP = { :normal => { :l => :link },
                    :link => { :q => :normal, :'10' => :normal } }

  def dealstate(fdlist, state, char, lastid)
    curr_id = @menu.current(1).to_i
    return [lastid, state] if curr_id == bib.opts[:ancestor] && :l == char
    newstate = KEY_STATE_MAP[state][char] || state

    if newstate != state
      lastid = curr_id
      chstate(fdlist, lastid, state, newstate)
    end

    [lastid, newstate]
  end

  def ask_outfile
    listdiag(:file) { |word| set_state(File.expand_path(word)) }
  end

  def chstate(fdlist, lastid, state, newstate)
    if state == :normal && newstate == :link
      @lastnode = fdlist.tree.find(:id, lastid)
      @lastnodestate, @lastnode.ostate = @lastnode.ostate, nil
      showmessage(Message::INDCSTC[:pkey])
    elsif state == :link && newstate == :normal
      @lastnode.ostate = @lastnodestate
      showmessage('')
    end
    @menu.set
  end
end

# Mapping the functions to keyboard
module CmdBibControl
  def cstat
    @stat = @stat == :content ? :list : :content
    visible = @stat == :content ? [COLORS[:list][0]] + [nil] * 3 : [*COLORS[:list], false]
    @list.setcol(visible)
  end

  OPEN_LOG = File.expand_path('~/.opbib_history')
  def listhistory
    FileUtils.touch(OPEN_LOG) unless File.exist?(OPEN_LOG)
    identlist ||= File.new(OPEN_LOG).each
                  .map { |line| line.split(' ')[-1] }.reverse.uniq[0..30]
    @list.set(0, 0, listidents(identlist))
  end

  def listkeys
    lastid = 0
    key = @menu.get(1) do |fdlist, state, char|
      keycontrol(state, char, [@menu.current(1).to_i, lastid])
      showc

      lastid, state = dealstate(fdlist, state, char, lastid)
      state
    end

    @list.set(0, 0, keyidents(key)) if @menu.char != 'q'
  end

  def listall
    whole_list = bib.db.select(:bibref, %w(identifier id title))
                 .map { |x| [x[0], bib.keynames(x[1]), x[2], x[1]] }
                 .sort_by { |x| x[3] }.transpose
    @list.set(0, 0, whole_list)
  end

  def refreshpanel(listref = true)
    listrefresh if listref
    clear
    refresh
    showc
    @list.mrefresh
  end

  def searchdiag
    listdiag { |word| @list.set(0, 0, search(word)) }
  end

  def add
    return unless asks(:add)

    filename = diag_with_msg(:file, :fileadr)
    bibname = diag_with_msg(:file, :bibadr)

    return if filename == '' || bibname == ''

    addresult = bib.addbib(filename, bibname)
    showmessage("The item aready exist, modify it") if addresult == :mod
    back_bibfile(bibname)
  end

  def delete
    bib.debib(@list.current(-1), "y\n") if asks(:delete)
  end

  NOTEADD = %w(o O)
  BIBNOTEKEY = %w(bibnote title author identifier)
  NOTEKEY = %w(note title author identifier)
  def noting
    return if @list.current(-1) == ''
    clear

    bib.storenote(@list.current(-1), getnotes)
    refreshpanel(false)
  end

  def getnotes
    pad = NoteItf.new(getnoteopt)

    pad.deal { |ch| send(*MAINFUNCHASH[ch.to_sym]) if NOTEADD.include?(ch) }
    pad.note.notes
  end

  def getnoteopt
    info = bib.db.select(:bibref, BIBNOTEKEY, :id, @list.current(-1)).flatten
    opt = NOTEKEY.map(&:to_sym).zip(info).to_h.merge(@opt)
    opt
  end

  def tag_current
    ltb = bib.keys(@list.current(-1))
    ltb.each { |k| @menu.fdlist.tag(k)  }
    @menu.set

    keyid = @menu.get(1) { |_, state, _| showc; state }
    bib.link_item(keyid, @list.current(-1)) if @menu.char != 'q' && asks(:tag)

    ltb.each { |k| @menu.fdlist.tag(k)  }
    @menu.set
  end

  def update
    return unless asks(:update)

    filename = diag_with_msg(:file, :fileask)
    bibname = diag_with_msg(:file, :bibask)

    update_item(bibname) if bibname != ''

    ident = bib.db.select(:bibref, :identifier, :id, @list.current(-1))[0][0]
    bib.addfile(filename, ident) if filename != ''
  end

  def open(associate)
    @list.current(-1) != '' && bib.opbib(@list.current(0), associate)
  end

  def print_item(kind)
    ask_outfile unless @outfile
    return unless @outfile
    bibtext, message = bibinfo(kind)

    bib.printbibs(bibtext, @outfile)
    showmessage("#{message} are printed")
  end

  def bibinfo(kind)
    if kind == :all
      return bib.db.select(:bibref, :id).flatten, "All items"
    elsif kind == :current
      return [@list.current(-1)], "item #{@list.current(0)}"
    end
  end

  def add_ancestorkey(_)
    keyname = diag_with_msg(nil, :newkey)
    bib.addkey(keyname, bib.opts[:ancestor]) unless keyname == ''
  end

  def addkey(ids)
    keyname = diag_with_msg(nil, :newkey)
    bib.addkey(keyname, ids[0]) unless keyname == ''
  end

  def delkey(ids)
    bib.dekey(ids[0]) if asks(:delete)
  end

  def modkey(ids)
    keyname = diag_with_msg(nil, :modkey)
    bib.modkey(ids[0], keyname) unless keyname == ''
  end

  def linkey(ids)
    bib.adopt(ids[1], ids[0])
  end

  MAINFUNCHASH = { # methods that change the shown list
    c: [:cstat],
    h: [:listhistory],
    l: [:listkeys],
    L: [:listall],
    R: [:refreshpanel],
    s: [:searchdiag],
    # methods that change the sqlite data
    a: [:add],
    d: [:delete],
    n: [:noting],
    t: [:tag_current],
    u: [:update],
    # methods that change nothing
    o: [:open, false],
    O: [:open, true],
    p: [:print_item, :current],
    P: [:print_item, :all],
  }

  MENUFUNC = { # methods to deal with keys
    normal: { A: :add_ancestorkey,
              a: :addkey,
              d: :delkey,
              m: :modkey },
    null: {},
    link: { :'10' => :linkey }
  }

  def control(char)
    MAINFUNCHASH[char.to_sym] && send(*MAINFUNCHASH[char.to_sym])
    showc
  end

  def keycontrol(state, char, currents)
    if MENUFUNC[state] && MENUFUNC[state][char]
      send(MENUFUNC[state][char], currents)
      @menu.set(bib.biblist)
    end

    showc
  end
end

# The main class for cmdbib, including the descriptions for the interface
class CmdBib < CmdBibBase
  include Message
  include CmdBibControl
  attr_reader :list

  public

  def initialize(hght, wth, bib, backup_bib)
    super(bib)
    @opt = [:scheight, :scwidth].zip([hght, wth]).to_h
    @backup_bib = File.expand_path(backup_bib)
    @stat = :content

    @diag = Insmode.new('', [@opt[:scheight] / 3, @opt[:scwidth] / 20],
                        [1, @opt[:scwidth] * 0.9], :cmd, ['|', '-'])
    inimenu(wth, hght)
    inilist(wth, hght)
  end

  def inilist(wth, hght)
    shifts = [0, [wth / 6, 25].max, [wth * 2 / 7, 45].max, wth - 2]
    @list = AdvMenu.new([[]] * 4, xshift: shifts[0..2],
                                  width: shifts[3] - shifts[2],
                                  length: hght - 3)
    @list.setctrl(['q'], DOWNKEYS + [10], UPKEYS)
    @list.setcol([COLORS[:list][0], false, false, false])
    iniwindows(hght - 3, wth, shifts[1])
  end

  def inimenu(wth, hght)
    @menu = FoldMenu.new(bib.biblist,
                         xshift: [(wth - bib.biblist.size) / 2],
                         yshift: 2, fixlen: nil, length: hght - 6)
    @menu.setctrl(['q', 10], DOWNKEYS, UPKEYS)
    @menu.setcol([COLORS[:menu]])
  end

  def deal
    @list.get(3, ->() { showmessage('') }) { |_, char| control(char) }
  end

  private

  UPKEYS = ['k', KEY_UP]
  DOWNKEYS = ['j', KEY_DOWN, 9, ' ']

  def iniwindows(length, wth, s1)
    @content = Content.new(length, wth, s1, bib)
    @state = Framewin.new(1, wth - s1 - 2, length - 1, s1, %w(| -))
    set_state

    @content.win.refresh
    @state.refresh
  end

  def set_state(outfile = nil)
    @outfile = outfile

    @state.cont.setpos(0, 0)
    @state.cont.attrset(A_BOLD)
    @state.cont.attron(color_pair(COLORS[:output]))
    @state.cont.addstr("Outfile: #{@outfile}")
  end

  def showc
    @content.show(@list.current(-1)) if @stat == :content
    @state.refresh
    true
  end
end
