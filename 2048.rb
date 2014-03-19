require 'json'

class TwoZeroFourEight

  HI_SCORES = File.join('/tmp/hi_scores_2048')

  COLOR = {0    => [48, 5, 232], 2    => [48, 5, 237],
           4    => [48, 5, 58],  8    => [48, 5, 70],
           16   => [48, 5, 40],  32   => [48, 5, 49],
           64   => [48, 5, 21],  128  => [48, 5, 56],
           256  => [48, 5, 53],  512  => [48, 5, 160],
           1024 => [48, 5, 202], 2048 => [48, 5, 226],
           :off => [48, 5, 235], :on  => [48, 5, 255]}

  ANSI = -> num, *rest { 0x1b.chr << ?[ << [*COLOR[num], *rest].join(?;) << ?m }

  class Tile
    def initialize(value = 0) @value = value end
    def to_i;  @value end
    def clear; @value = 0 end
    def spawn; @value = (rand > 0.95 ? 4 : 2) end
    def zero?; @value.zero? end
    def nonzero?; !zero? end
    def block; ANSI[@value] << ?\s << ANSI[nil, 0] end
    def to_s
      ANSI[0, 1] << ( zero? ? (?\s*4) : ('%4d' % @value) ) << ANSI[nil, 0]
    end
  end

  attr_reader :turn, :score

  def level
    @tiles.flatten.map(&:to_i).max
  end

  def border(direction = nil)
    ( @last == direction ? ANSI[:on] : ANSI[:off] ) << (?\s*2) << ANSI[nil, 0]
  end

  def add_border(string)
    string << border(:left) << yield << border(:right) << ?\n
  end

  def to_s
    ''.tap do |string|
      string << border << (border(:up)*16) << border << ?\n

      @tiles.each.with_index do |row, index|
        add_border(string) { row.map { |t| t.block*8 }.join }
        add_border(string) { row.map { |t| (t.block*2) << t.to_s << (t.block*2) }.join }
        add_border(string) { row.map { |t| t.block*8 }.join }
      end

      string << border << (border(:down)*16) << border << ?\n
    end
  end

  def compress(tiles)
    tiles = tiles.map.with_index do |tile, index|
      if ( other = tiles[index.next] ) && (tile.to_i == other.to_i)
        other.clear
        @score += tile.to_i

        Tile.new(tile.to_i * 2)
      else
        tile
      end
    end

    tiles.reject! &:zero?
    tiles.unshift Tile.new until tiles.count == 4
    tiles
  end

  def game_over?; win? || @overfilled end
  def win?; @tiles.flatten.any? { |t| t.to_i == 2048 } end

  def empty_tile
    @tiles.flatten.select(&:zero?).sample
  end

  def execute(direction)
    @turn += 1

    state = @tiles.map { |row| row.map &:to_i }

    case @last = direction
    when :up    then @tiles = @tiles.transpose.map { |row| compress(row.reject(&:zero?).reverse).reverse }.transpose
    when :down  then @tiles = @tiles.transpose.map { |row| compress(row.reject &:zero?) }.transpose
    when :left  then @tiles.map! { |row| compress(row.reject(&:zero?).reverse).reverse }
    when :right then @tiles.map! { |row| compress(row.reject &:zero?) }
    end

    new_state = @tiles.map { |row| row.map &:to_i }

    if state.flatten.inject(&:+).zero? || state != new_state
      tile = empty_tile and tile.spawn
    end

    @overfilled = @tiles.flatten.all?(&:nonzero?) if state == new_state
  end

  def gets
    begin
      old_state = `stty -g`.chomp
      system 'stty raw -echo'
      char = STDIN.getc
      if char == 0x1b.chr
        char << STDIN.getc
        char << STDIN.getc
      end
    rescue => error
      warn error.message, error.backtrace
    ensure
      system 'stty', old_state
    end
    char
  end

  def move
    case value = gets[-1]
    when ?A then execute :up
    when ?B then execute :down
    when ?C then execute :right
    when ?D then execute :left
    when ?\C-c, ?\C-x, ?x, ?q then exit
    end
  end

  def initialize
    @last = @score = @turn = 0
    @tiles = Array.new(4) { Array.new(4) { Tile.new } }
  end

  def hi_scores
    Hash.new(0).merge read
  end

  def read
    JSON.parse(File.read HI_SCORES)
  rescue JSON::ParserError, Errno::ENOENT
    {}
  end

  def write(hi_scores)
    File.write HI_SCORES, JSON.pretty_generate(hi_scores)
  end
end

tzfe = TwoZeroFourEight.new

STDIN.reopen('/dev/tty')
system 'clear'
puts tzfe

until tzfe.game_over?
  tzfe.move
  system 'clear'
  puts tzfe
end

scores = tzfe.hi_scores

print 'Game Over - '
scores['games'] += 1
if tzfe.win?
  scores['wins'] += 1
  print 'YOU WIN! (win/lose '
else
  print 'YOU LOSE! (win/lose '
end
puts "#{scores['wins']}:#{scores['games'] - scores['wins']})"

scores['hi_level'] = tzfe.level if tzfe.level> scores['hi_level']
puts "Level: #{tzfe.level} (best: #{scores['hi_level']})"
scores['hi_turns'] = tzfe.turn if tzfe.turn > scores['hi_turns']
puts "Turn:  #{tzfe.turn} (best: #{scores['hi_turns']})"
scores['hi_score'] = tzfe.score if tzfe.score > scores['hi_score']
puts "Score: #{tzfe.score} (best: #{scores['hi_score']})"

tzfe.write scores

