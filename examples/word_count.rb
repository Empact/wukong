#!/usr/bin/env ruby
$: << File.dirname(__FILE__)+'/../wukong'
require 'wukong'



module WordCount
  class Mapper < Wukong::Streamer

    #
    # Split a string into its constituent words.
    #
    # This is pretty simpleminded:
    # * downcase the word
    # * Split at any non-alphanumeric boundary, including '_'
    # * However, preserve the special cases of 's or 't at the end of a
    #   word.
    #
    #   tokenize("Jim's dawg won't hunt: dawg_hunt error #3007a4")
    #   # => ["jim's", "dawd", "won't", "hunt", "dawg", "hunt", "error", "3007a4"]
    #
    def tokenize str
      return [] unless str
      str = str.downcase;
      # kill off all punctuation except 's
      # this includes hyphens (words are split)
      str = str.
        gsub(/[^a-zA-Z0-9\']+/, ' ').
        gsub(/\'([st])\b/, '!\1').gsub(/\'/, ' ').gsub(/!/, "'")
      # Busticate at whitespace
      words = str.strip.split(/\s+/)
      words.reject!{|w| w.blank? }
      words
    end

    #
    # Emit each word in each line.
    #
    def stream
      $stdin.each do |line|
        tokenize(line).each{|word| puts [word, 1].join("\t") }
      end
    end
  end

  class Reducer < Wukong::CountingReducer
  end

  #
  #
  class Script < Wukong::Script
  end
end

#
# Executes the script
#
WordFreq::Script.new(
  WordFreq::Mapper,
  WordFreq::Reducer
  ).run
