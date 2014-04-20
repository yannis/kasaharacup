require 'spec_helper'

describe Event do
  it {should belong_to :cup}
  it {should validate_presence_of :cup_id}
  it {should validate_presence_of :name_fr}
  it {should validate_presence_of :name_en}
  it {should validate_presence_of :start_on}
end
