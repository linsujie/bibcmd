#!/bin/env ruby
# encoding: utf-8

module DriverUtils
  KEY_ESC = 27
  KEY_ENT = 10
  KEY_TAB = 9
  KEY_BAC1 = 127
  KEY_BAC2 = 263

  def format_cmd(key, mode = :normal)
    format_str =->(k) { k.to_s.split('').map(&:ord).unshift(nil)[-2..-1] }

    record_cmd(key.is_a?(Fixnum) ? [nil, key] : format_str.call(key), mode)
  end

  def record_cmd(cmd, mode)
    @pre_key ||= {}
    @pre_key[mode] ||= []
    (@pre_key[mode] << cmd[0]) && @pre_key[mode].uniq if cmd[0]

    cmd
  end
end
