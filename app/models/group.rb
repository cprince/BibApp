require 'machine_name'
require 'solr_helper_methods'
require 'solr_updater'

class Group < ActiveRecord::Base
  include MachineNameUpdater
  include SolrHelperMethods
  include SolrUpdater

  acts_as_tree :order => "name"
  acts_as_authorizable #some actions on groups require authorization

  #### Associations ####

  has_many :people,
           :through => :memberships,
           :order => "last_name, first_name"
  has_many :memberships

  scope :hidden, where(:hide => true)
  scope :unhidden, where(:hide => false)
  scope :upper_name_like, lambda { |name| where('upper(name) like ?', name) }
  scope :name_like, lambda { |name| where('name like ?', name) }
  scope :order_by_upper_name, order('upper(name)')
  scope :order_by_name, order('name')
  #### Callbacks ####

  before_save :update_machine_name

  # return the first letter of each name, ordered alphabetically
  def self.letters
    self.unhidden.select('DISTINCT SUBSTR(name, 1, 1) AS letter').order('letter').collect {|x| x.letter.upcase}
  end

  #Parse Solr data (produced by to_solr_data)
  # return Group name and ID
  def self.parse_solr_data(group_data)
    data = group_data.split("||")
    name = data[0]
    id = data[1]

    return name, id
  end

  #### Methods ####

  def works
    Work.verified.includes(:contributorships => {:person => :memberships}).
        where(:contributorships => {:person => {:memberships => {:group_id => self.id}}})
  end

  def get_associated_works
    self.works
  end

  def require_reindex?
    self.name_changed? or self.machine_name_changed? or self.hide_changed?
  end

  # Convert object into semi-structured data to be stored in Solr
  def to_solr_data
    "#{name} || #{id}"
  end

  def solr_filter
    %Q(group_id:"#{self.id}")
  end

  #Add an http:// if this (or https://) isn't found before the url
  #hoped to be able to use URI to do this more nicely, but haven't figured it out yet
  def canonicalize_url
    uri = URI.parse(self.url)
    return self.url if ['http', 'https'].include?(uri.scheme)
    return 'http://' + self.url
  rescue URI::InvalidURIError
    return "#"
  end

  #TODO acts_as_tree isn't really all that great, and we may want to replace it sometime
  #Note that it provides methods: parent, children, siblings, self_and_siblings,
  #ancestors, and root. As an example, we might use a nested_set gem (maybe better_nested_set)). It should
  #almost drop in - create the columns lft/rgt in a migration, put acts_as_nested_set
  #in the class definition, and run renumber_full_tree to generate the left/right indexes.

  #Return the group's top-level parent (ancestor)
  def top_level_parent
    self.root
  end

  def ancestors_and_descendants
    self.ancestors + self.descendants
  end

  def descendants
    self.children.map(&:descendants).flatten + self.children
  end

end