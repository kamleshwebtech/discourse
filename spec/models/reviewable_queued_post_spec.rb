require 'rails_helper'

RSpec.describe ReviewableQueuedPost, type: :model do

  let(:reviewable) { Fabricate(:reviewable_queued_post) }
  let(:moderator) { Fabricate(:moderator) }

  context "create" do
    it "triggers queued_post_created" do
      event = DiscourseEvent.track(:queued_post_created) { reviewable.save! }
      expect(event).to be_present
      expect(event[:params][0]).to eq(reviewable)
    end
  end

  context "actions" do

    context "approve" do
      it 'triggers an extensibility event' do
        event = DiscourseEvent.track(:approved_post) { reviewable.perform(moderator, :approve) }
        expect(event).to be_present
        expect(event[:params].first).to eq(reviewable)
      end
    end

    context "reject" do
      it 'triggers an extensibility event' do
        event = DiscourseEvent.track(:rejected_post) { reviewable.perform(moderator, :reject) }
        expect(event).to be_present
        expect(event[:params].first).to eq(reviewable)
      end
    end
  end

end
