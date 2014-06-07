class Purchase < ActiveRecord::Base
  belongs_to :kenshi, inverse_of: :purchases
  belongs_to :product, inverse_of: :purchases
end
