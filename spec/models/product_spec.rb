require 'spec_helper'

describe Product do

  it {should have_many(:purchases).dependent(:destroy)}
  it {should have_many(:kenshis).through(:purchases)}

  it {should belong_to :cup}
  it {should belong_to :event}

  it {should respond_to :name_en}
  it {should respond_to :name_fr}
  it {should respond_to :description_en}
  it {should respond_to :description_fr}
  it {should respond_to :fee_chf}
  it {should respond_to :fee_eu}

  it {should validate_presence_of :name_en}
  it {should validate_presence_of :name_fr}
  it {should validate_presence_of :cup_id}
  it {should validate_presence_of :fee_chf}
  it {should validate_presence_of :fee_eu}

  it {should validate_uniqueness_of(:name_en).scoped_to(:cup_id)}
  it {should validate_uniqueness_of(:name_fr).scoped_to(:cup_id)}

  it {should validate_numericality_of(:fee_chf)}
  it {should validate_numericality_of(:fee_eu)}
end
