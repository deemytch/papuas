class UsersServer < ActiveRecord::Base
  belongs_to :user
  belongs_to :server
end
