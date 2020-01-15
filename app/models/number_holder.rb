class NumberHolder < ApplicationRecord
  validates :number, presence: true

  def double_it
    self.number *= 2
  end
end
