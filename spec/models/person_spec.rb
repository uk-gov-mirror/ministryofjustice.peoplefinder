require 'rails_helper'

RSpec.describe Person, :type => :model do
  let(:person) { build(:person) }
  it { should validate_presence_of(:surname) }
  it { should have_many(:groups) }

  describe '.name' do
    before { person.surname = 'von Brown' }

    context 'with a given_name and surname' do
      it 'should concatenate given_name and surname' do
        person.given_name = 'Jon'
        expect(person.name).to eql('Jon von Brown')
      end
    end

    context 'with a surname only' do
      it 'should use the surname' do
        expect(person.name).to eql('von Brown')
      end
    end
  end

  context "completion score" do
    it "should be 0 if all fields are empty" do
      person = Person.new
      expect(person.completion_score).to eql(0)
      expect(person).not_to be_profile_completed
    end

    it "should be 50 if half the fields are filled" do
      person = Person.new(
        given_name: "Bobby",
        surname: "Tables",
        email: "user.example@digital.justice.gov.uk",
        phone: "020 7946 0123",
      )
      expect(person.completion_score).to eql(50)
      expect(person).not_to be_profile_completed
    end

    it "should be 100 if all fields are filled" do
      person = Person.new(
        given_name: "Bobby",
        surname: "Tables",
        email: "user.example@digital.justice.gov.uk",
        phone: "020 7946 0123",
        mobile: "07700 900123",
        location: "London",
        description: "I am a real person"
      )
      person.groups << build(:group)
      expect(person.completion_score).to eql(100)
      expect(person).to be_profile_completed
    end
  end

  context "slug" do
    it "should be generated from the first part of the email address if present" do
      person = create(:person, email: "user.example@digital.justice.gov.uk")
      person.reload
      expect(person.slug).to eql("user-example")
    end

    it "should be generated from the name if there is no email" do
      person = create(:person, given_name: "Bobby", surname: "Tables")
      person.reload
      expect(person.slug).to eql("bobby-tables")
    end
  end

  context "search" do
    it "should delete indexes" do
      expect(Person.__elasticsearch__).to receive(:delete_index!).with({ index: "test_people" })
      Person.delete_indexes
    end
  end

  context 'elasticsearch indexing helpers' do
    before do
      person.save!
      digital_services = create(:group, name: 'Digital Services')
      estates = create(:group, name: 'Estates')
      person.memberships.create(group: estates, role: 'Cleaner')
      person.memberships.create(group: digital_services, role: 'Designer')
    end

    it 'should write the role and group as a string' do
      expect(person.role_and_group).to match(/Digital Services, Designer/)
      expect(person.role_and_group).to match(/Estates, Cleaner/)
    end
  end
end
