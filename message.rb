#!/usr/bin/env ruby
# encoding: utf-8

require 'curses'

include Curses

# The basic normal mode
module Message
  private

  ASKSTC = { quit: 'The note has not been saved yet, do you want to quit?',
             store: 'Do you want to store this notes?',
             delete: 'Do you want to delete this item?',
             tag: 'Do you want to tag / untag this item to a key?',
             add: 'Do you want to add an item?',
             update: 'Do you want to update the bib?'
  }

  INDCSTC = { fileadr: 'Input the filename of the item',
              fileask: 'Input the filename (the file would not be updated if empty)',
              bibadr: 'Input the bibfile of the item',
              bibask: 'Input the bibfile (the item would not be updated if empty)',
              newkey: 'Input the name of the new key',
              pkey: 'Choose the parent key'
  }

  def asks(affairs)
    result = 'y' == showmessage(ASKSTC[affairs]).getch
    showmessage('')
    result
  end

  def showmessage(msg)
    win = Window.new(1, @opt[:scwidth], @opt[:scheight] - 1, 0)
    win.attrset(A_BOLD)
    win.attron(color_pair(COLORS[:message]))
    win.addstr(msg)
    win.refresh
    win
  end
end
