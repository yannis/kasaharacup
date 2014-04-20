require 'spec_helper'

describe Club do
  it { should have_many :users}
  it { should have_many :kenshis}
  it { should validate_presence_of :name}
  it { should validate_uniqueness_of :name}
end
