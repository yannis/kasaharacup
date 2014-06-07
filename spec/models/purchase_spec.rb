require 'spec_helper'

describe Purchase do
  it {should belong_to :kenshi}
  it {should belong_to :product}
end
