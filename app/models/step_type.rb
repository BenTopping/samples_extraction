require 'support_n3'

class StepType < ActiveRecord::Base

  before_update :remove_previous_conditions
  after_save :create_next_conditions

  has_many :activity_type_step_types
  has_many :activity_types, :through => :activity_type_step_types
  has_many :condition_groups
  has_many :actions

  has_many :action_subject_condition_groups, :through => :actions, :source => :subject_condition_group
  has_many :action_object_condition_groups, :through => :actions, :source => :object_condition_group

  include Deprecatable

  scope :with_template, ->() { where('step_template is not null')}

  scope :for_reasoning, ->() { where(:for_reasoning => true)}

  def fact_css_classes
    {
      'addFacts' => 'glyphicon glyphicon-pencil',
      'removeFacts' => 'glyphicon glyphicon-erase',
      'createAsset' => 'glyphicon glyphicon-plus',
      'selectAsset' => 'glyphicon glyphicon-eye-open',
      'unselectAsset' => 'glyphicon glyphicon-eye-close',
      'checkFacts' => 'glyphicon glyphicon-search'
    }
  end

  def all_step_templates
    #Dir["app/views/step_types/step_templates/*"].concat([''])
    ['', 'transfer_tube_to_tube', 'upload_file_step']
    Dir["app/views/step_types/step_templates/*"].map do |s|
      name = File.basename(s)
      name.gsub!(/^_/, '')
      name.gsub!(/\.html\.erb$/, '')
      name
    end.concat([''])
  end

  def condition_groups_init
    cgroups = condition_groups.reduce({}) do |memo, condition_group|
      name = condition_group.name || "a#{condition_group.id}"
      memo[name] = {
        :cardinality => condition_group.cardinality,
        :keepSelected => condition_group.keep_selected,
        :facts =>  condition_group.conditions.map do |condition|
          {
            :cssClasses => fact_css_classes['checkFacts'],
            :name => name,
            :actionType => 'checkFacts',
            :predicate => condition.predicate,
            :object => condition.object
          }
        end
      }
      memo
    end
    agroups = actions.reduce(cgroups) do |memo, action|
      name = action.subject_condition_group.name || "a#{action.subject_condition_group.id}"
      memo[name]={:facts => []} unless memo[name]
      memo[name][:facts].push({
          :cssClasses => fact_css_classes[action.action_type],
          :name => name,
          :actionType => action.action_type,
          :predicate => action.predicate,
          :object => action.object
        })
      memo
    end
    agroups.to_json
  end

  def create_next_conditions
    unless n3_definition.nil?
      SupportN3::parse_string(n3_definition, {}, self)
    end
  end

  def remove_previous_conditions
    condition_groups.each do |condition_group|
      condition_group.conditions.each(&:destroy)
      condition_group.destroy
    end
    actions.each do |action|
      action.update_attributes(:step_type_id => nil)
    end
  end

  def condition_group_classification_for(assets)
    related_assets = []
    h = Hash[assets.map{|asset| [asset, condition_groups_for(asset, related_assets)]}]
    related_assets.each do |a|
      h[a]= condition_groups_for(a)
    end
    h
  end

  def every_condition_group_satisfies_cardinality(classification)
    # http://stackoverflow.com/questions/10989259/swapping-keys-and-values-in-a-hash
    inverter_classification = classification.each_with_object({}) do |(k,v),o|
      v.each do |cg|
        (o[cg]||=[])<<k
      end
    end
    inverter_classification.keys.all? do |condition_group|
      condition_group.cardinality.nil? || (condition_group.cardinality==0) ||
        (condition_group.cardinality >= inverter_classification[condition_group].length)
    end
  end

  def every_condition_group_has_at_least_one_asset?(classification)
    (classification.values.flatten.uniq.length == condition_groups.length)
  end

  def every_asset_has_at_least_one_condition_group?(classification)
    (classification.values.all? do |condition_group|
      ([condition_group].flatten.length>=1)
    end)
  end

  def every_required_asset_is_in_classification?(classification, required_assets)
    return true if required_assets.nil?
    required_assets.all?{|asset| !classification[asset].empty?}
  end

  def compatible_with?(assets, required_assets=nil)
    assets = Array(assets)
    # Every asset has at least one condition group satisfied
    classification = condition_group_classification_for(assets)
    compatible = every_condition_group_satisfies_cardinality(classification) &&
    every_condition_group_has_at_least_one_asset?(classification) &&
      every_asset_has_at_least_one_condition_group?(classification) &&
      every_required_asset_is_in_classification?(classification, required_assets)
    return true if compatible
    return false
  end

  def condition_groups_for(asset, related_assets = [])
    condition_groups.select do |condition_group|
      condition_group.conditions_compatible_with?(asset, related_assets)
    end
  end

  def actions_for_condition_group(condition_group)
  end

  def actions_for(assets)
    #condition_group_classification_for(assets)
  end

end
