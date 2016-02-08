#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'bibus_utils.rb'

# The content panel of cmdbib_utils, initialized with the size information and
# providing a method 'show' which require the content
class Content
  attr_reader :win, :info

  def initialize(length, wth, shift, bib)
    @win = Framewin.new(length - 2, wth - shift - 2, 0, shift, %w(| -))
    @bib = bib
  end

  CONTINFO = %w(title author id journal volume pages eprint bibnote)
  ITEMHEAD = { title: '', author: "\n", keyname: "\n", journal: '  ',
               volume: ' ', pages: ' ', eprint: '  ', bibnote: "\n\n" }
  JNLHASH = { '\prd' => 'PRD', '\apj' => 'ApJ', '\jcap' => 'JCAP',
              '\apjl' => 'ApJL', '\mnras' => 'MNRAS',
              '\aap' =>  'Astron.Astrophys.', '\solphys' => 'Solar Physics'
  }

  def show(id)
    info = @bib.db.select(:bibref, CONTINFO, :id, id).flatten

    @info = !info.empty? && forminfo(CONTINFO.map(&:to_sym).zip(info).to_h)

    printcontent
  end

  private

  def printcontent
    @win.cont.clear
    print2win if @info
    @win.freshframe
    @win.cont.refresh
  end

  def print2win
    @win.cont.setpos(0, 0)
    printinfo(:title)

    @win.cont.attrset(A_BOLD)
    %w(author keyname journal volume pages eprint).map(&:to_sym)
      .each { |x| printinfo(x) }
    @win.cont.attroff(A_BOLD)

    printinfo(:bibnote, BaseBibUtils.fmtnote(@info[:bibnote]))
  end

  def printinfo(item, cont = nil)
    return unless @info[item] != ''
    @win.cont.attron(color_pair(COLORS[item]))
    @win.cont.addstr(ITEMHEAD[item] + (cont || @info[item].to_s))
  end

  def forminfo(info)
    info[:author] = Author.short(info[:author])
    info[:keyname] = @bib.keynames(info[:id])
    info[:journal] = (JNLHASH[info[:journal]] || info[:journal])
    info
  end
end
