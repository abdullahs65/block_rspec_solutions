# Provides an abstraction for performing boolean operations on a numerical range.
# Used for calculating the interaction of free and busy time periods on a schedule.
#
# A Block is a VALUE OBJECT which has a starting value (called `top` or `start`)
# and an ending value (called `bottom` or `end`). These properties are numeric
# values which could represent points in time, or an arbitrary numeric scale.
#
# Blocks can be combined and subtracted from one another to yield other blocks
# or arrays of blocks depending on whether the original blocks are contiguous or not.
#
# For example:
#   Addition of overlapping ranges:
#   Block.new(3, 8) + Block.new(5, 12) == Block.new(3, 12)
#
#   Subtraction of one block from the middle of another:
#   Block.new(5, 25) - Block.new(10, 20) == [Block.new(5, 10), Block.new(20, 25)]
#
class Block

  def initialize(from, to)
    if to < from
      @start, @end = to, from
    else
      @start, @end = from, to
    end
  end

  def inspect
    { :start => self.start, :end => self.end }.inspect
  end

  attr_reader :start, :end

  alias :top :start

  alias :bottom :end

  # ==========
  # = Length =
  # ==========

  def length
    bottom - top
  end

  # ==============
  # = Comparison =
  # ==============

  def ==(other)
    top == other.top && bottom == other.bottom
  end

  def <=>(other)
    [top, bottom] <=> [other.top, other.bottom]
  end

  def include?(n)
    top <= n && bottom >= n
  end

  # ============
  # = Position =
  # ============

  # This block entirely surrounds the other block.

  def surrounds?(other)
    other.top > top && other.bottom < bottom
  end

  def covers?(other)
    other.top >= top && other.bottom <= bottom
  end

  # This block intersects with the top of the other block.

  def intersects_top?(other)
    top <= other.top && other.include?(bottom)
  end

  # This block intersects with the bottom of the other block.

  def intersects_bottom?(other)
    bottom >= other.bottom && other.include?(top)
  end

  # This block overlaps with any part of the other block.

  def overlaps?(other)
    include?(other.top) || other.include?(top)
  end

  # ==============
  # = Operations =
  # ==============

  # A block encompassing both this block and the other.

  def union(other)
    Block.new([top, other.top].min, [bottom, other.bottom].max)
  end

  # A two element array of blocks created by cutting the other block out of this one.

  def split(other)
    [Block.new(top, other.top), Block.new(other.bottom, bottom)]
  end

  # A block created by cutting the top off this block.

  def trim_from(new_top)
    Block.new(new_top, bottom)
  end

  # A block created by cutting the bottom off this block.

  def trim_to(new_bottom)
    Block.new(top, new_bottom)
  end

  def limited(limiter)
    Block.new([top, limiter.top].max, [bottom, limiter.bottom].min)
  end

  def padded(top_padding, bottom_padding)
    Block.new(top - [top_padding, 0].max, bottom + [bottom_padding, 0].max)
  end

  # =============
  # = Operators =
  # =============
  
  # Return the result of adding the other Block (or Blocks) to self.

  def add(other)
    overlaps?(other) ? [union(other)] : [other, self]
  end
  
  # Return the result of subtracting the other Block (or Blocks) from self.

  def subtract(other)  
    if other.class == Array
      new_params = []
      other.each do |block|
        new_params << block.start if self.include?(block.start) 
        new_params << block.end  if self.include?(block.end)
      end
      [Block.new(new_params[0], new_params[1]), Block.new(new_params[2], new_params[3])]
    else  
      return [] if self == other
      if surrounds?(other)
        split(other)
      elsif covers?(other) 
        if intersects_top?(other)
          [trim_to(other.start)]
        elsif intersects_bottom?(other)  
          [trim_from(other.end)]
        end
      elsif overlaps?(other) && other.bottom == top
        [self]
      else
        []
      end
    end 
  end

  alias :- :subtract

  alias :+ :add

  # An array of blocks created by adding each block to the others.

  def self.merge(blocks)
    blocks.sort_by(&:top).inject([]) do |blocks, b|
      if blocks.length > 0 && blocks.last.overlaps?(b)
        blocks[0...-1] + (blocks.last + b)
      else
        blocks + [b]
      end
    end
  end

  def merge(others)
    blocks = []
    i = 0
    issolated_count = 0
    others.each do |block|
      if i == 0
        current_block = self
        comp_block = block
      elsif i == (others.count - 1)
        current_block = block
        comp_block = others[i - 1]
      else
        current_block = block
        comp_block = others[i + 1]
      end 
      if current_block.overlaps?(comp_block)
        blocks << Block.new(current_block.start, comp_block.end)
      else
        issolated_count +=1
      end
      if issolated_count == 2
        blocks << Block.new(block.start, block.end)
      end  
      i += 1
    end
    blocks
  end
end
