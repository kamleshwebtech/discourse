require_dependency 'reviewable'

class ReviewableQueuedPost < Reviewable

  after_create do
    # Backwards compatibility, new code should listen for `reviewable_created`
    DiscourseEvent.trigger(:queued_post_created, self)
  end

  def build_actions(actions, guardian, args)
    return unless pending?

    actions.add(:approve) if guardian.is_staff?
    actions.add(:reject) if guardian.is_staff?
  end

  def build_editable_fields(fields, guardian, args)
    return unless guardian.is_staff?

    # We can edit category / title if it's a new topic
    if topic_id.blank?
      fields.add('category_id', :category)
      fields.add('payload.title', :text)
    end

    fields.add('payload.raw', :editor)
  end

  def perform_approve(performed_by, args)
    created_post = nil

    create_opts = payload.symbolize_keys
    create_opts[:cooking_options].symbolize_keys! if create_opts[:cooking_options]
    create_opts[:topic_id] = topic_id if topic_id

    creator = PostCreator.new(performed_by, create_opts.merge(
      skip_validations: true,
      skip_jobs: true,
      skip_events: true
    ))
    created_post = creator.create

    unless created_post && creator.errors.blank?
      return PerformResult.new(:failure, errors: creator.errors)
    end

    # TODO: silence user is an option here
    # TODO: Log post approval
    # StaffActionLogger.new(approved_by).log_post_approved(created_post)

    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:approved_post, self, created_post)

    PerformResult.new(:success, transition_to: :approved)
  end

  def perform_reject(performed_by, args)
    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:rejected_post, self)

    PerformResult.new(:success, transition_to: :rejected)
  end

end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint(8)        not null, primary key
#  type                    :string           not null
#  status                  :integer          default(0), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  reviewable_by_group_id  :integer
#  claimed_by_id           :integer
#  category_id             :integer
#  target_id               :integer
#  target_type             :string
#  payload                 :json
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  topic_id                :integer
#
# Indexes
#
#  index_reviewables_on_status              (status)
#  index_reviewables_on_status_and_type     (status,type)
#  index_reviewables_on_type_and_target_id  (type,target_id) UNIQUE
#
