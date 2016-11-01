class Person < ActiveRecord::Base
  include Concerns::Acquisition
  include Concerns::Activation
  include Concerns::Completion
  include Concerns::WorkDays
  include Concerns::ExposeMandatoryFields
  include Concerns::GeckoboardDatasets

  belongs_to :profile_photo

  extend FriendlyId
  friendly_id :slug_source, use: :slugged

  def slug_source
    email.present? ? email.split(/@/).first : name
  end

  include Concerns::Searchable

  def as_indexed_json(_options = {})
    as_json(
      only: [:description, :location_in_building, :building, :city, :current_project],
      methods: [:name, :role_and_group]
    )
  end

  has_paper_trail class_name: 'Version',
                  ignore: [:updated_at, :created_at, :id, :slug, :login_count, :last_login_at,
                           :last_reminder_email_at]

  def changes_for_paper_trail
    super.tap do |changes|
      changes['image'].map! { |img| img.url && File.basename(img.url) } if changes.key?('image')
    end
  end

  include Concerns::Sanitizable
  sanitize_fields :given_name, :surname, strip: true, remove_digits: true
  sanitize_fields :email, strip: true, downcase: true

  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h
  after_save :crop_profile_photo
  after_save :enqueue_group_completion_score_updates

  attr_accessor :skip_group_completion_score_updates
  skip_callback :save, :after, :enqueue_group_completion_score_updates, if: :skip_group_completion_score_updates

  def enqueue_group_completion_score_updates
    groups_prior = groups
    reload # updates groups
    groups_current = groups

    (groups_prior + groups_current).uniq.each do |group|
      UpdateGroupMembersCompletionScoreJob.perform_later(group)
    end
  end

  def crop_profile_photo(versions = [])
    profile_photo.crop crop_x, crop_y, crop_w, crop_h, versions if crop_x.present?
  end

  mount_uploader :legacy_image, ImageUploader, mount_on: :image, mount_as: :image

  def profile_image
    if profile_photo
      profile_photo.image
    elsif attributes['image']
      legacy_image
    end
  end

  validates :given_name, presence: true, on: :update
  validates :surname, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, email: true
  validates :secondary_email, email: true, allow_blank: true

  has_many :memberships, -> { includes(:group).order('groups.name') }, dependent: :destroy
  has_many :groups, through: :memberships

  accepts_nested_attributes_for :memberships, allow_destroy: true,
    reject_if: proc { |membership| membership['group_id'].blank? }

  default_scope { order(surname: :asc, given_name: :asc) }

  scope :never_logged_in, -> { where(login_count: 0) }

  scope :logged_in_at_least_once, -> { where('people.login_count > 0') }

  scope :last_reminder_email_older_than, lambda { |within|
    where('last_reminder_email_at IS ? OR last_reminder_email_at < ?', nil, within)
  }

  scope :updated_at_older_than, -> (within) { where('updated_at < ?', within) }

  scope :created_at_older_than, -> (within) { where('created_at < ?', within) }

  def self.namesakes(person)
    where(surname: person.surname, given_name: person.given_name).where.not(id: person.id)
  end

  def self.all_in_groups_from_clause(groups)
    joins(:memberships).
      where(memberships: { group_id: groups }).
      select("people.*,
            string_agg(CASE role WHEN '' THEN NULL ELSE role END, ', ' ORDER BY role) AS role_names"
            ).
      group(:id).
      uniq
  end

  scope :all_in_groups_scope, -> (groups) { from(all_in_groups_from_clause(groups), :people) }
  scope :all_in_subtree, -> (group) { from(all_in_groups_from_clause(group.subtree_ids), :people) }

  # Does not return ActiveRecord::Relation
  # - see all_in_groups_scope alternative
  # TODO: remove when not needed
  def self.all_in_groups(group_ids)
    query = <<-SQL
      SELECT DISTINCT p.*,
        string_agg(CASE role WHEN '' THEN NULL ELSE role END, ', ' ORDER BY role) AS role_names
      FROM memberships m, people p
      WHERE m.person_id = p.id AND m.group_id in (?)
      GROUP BY p.id
      ORDER BY surname ASC, given_name ASC;
    SQL
    find_by_sql([query, group_ids])
  end

  def self.count_in_groups(group_ids, excluded_group_ids: [], excluded_ids: [])
    if excluded_group_ids.present?
      excluded_ids += Person.in_groups(excluded_group_ids).pluck(:id)
    end

    Person.in_groups(group_ids).where.not(id: excluded_ids).count
  end

  def self.in_groups(group_ids)
    Person.includes(:memberships).
      where("memberships.group_id": group_ids)
  end

  def to_s
    name
  end

  def role_and_group
    memberships.join('; ')
  end

  def path
    groups.any? ? groups.first.path + [self] : [self]
  end

  def phone
    [primary_phone_number, secondary_phone_number].find(&:present?)
  end

  include Concerns::ConcatenatedFields
  concatenated_field :location, :location_in_building, :building, :city, join_with: ', '
  concatenated_field :name, :given_name, :surname, join_with: ' '

  def at_permitted_domain?
    EmailAddress.new(email).permitted_domain?
  end

  def notify_of_change?(person_responsible)
    at_permitted_domain? && person_responsible.try(:email) != email
  end

  def reminder_email_sent? within:
    last_reminder_email_at.present? &&
      last_reminder_email_at.end_of_day >= within.ago
  end

  def email_address_with_name
    address = Mail::Address.new email
    address.display_name = name
    address.format
  end

end
