class User < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  scope :active, -> { where(status: "active") }
end
