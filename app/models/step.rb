
class Step < ActiveRecord::Base

  self.inheritance_column = :sti_type

  attr_accessor :wildcard_values

  belongs_to :activity
  belongs_to :step_type
  belongs_to :asset_group
  belongs_to :user
  has_many :uploads
  has_many :operations
  has_many :assets, through: :asset_group
  belongs_to :created_asset_group, :class_name => 'AssetGroup', :foreign_key => 'created_asset_group_id'
  belongs_to :next_step, class_name: 'Step', :foreign_key => 'next_step_id'

  serialize :printer_config

  scope :running_with_asset, ->(asset) { includes(:assets).where(asset_groups_assets: { asset_id: asset.id}, state: 'running') }
  scope :for_assets, ->(assets) { joins(:asset_group => :assets).where(:asset_groups_assets =>  {:asset_id => assets })}
  scope :for_step_type, ->(step_type) { where(:step_type => step_type)}  

  include QueueableJob
  include Deprecatable  
  include Steps::Job
  include Steps::Cancellable
  include Steps::Deprecatable
  include Steps::Retryable
  include Steps::State
  include Steps::WebsocketEvents
  include Steps::ExecutionActions
  include Lab::Actions

  def asset_group_assets
    asset_group ? asset_group.assets : []
  end


end
