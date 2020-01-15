require 'rails_helper'

RSpec.describe NumberHolder, type: :model do
  subject { NumberHolder.new }

  it 'is invalid without a number' do
    expect(subject).not_to be_valid
  end

  it 'doubles the number' do
    subject.number = 4

    expect { subject.double_it }.to change { subject.number }.from(4).to(8)
  end
end
