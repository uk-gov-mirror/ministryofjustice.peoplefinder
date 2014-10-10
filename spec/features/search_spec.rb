require 'rails_helper'

feature 'Search for people', elastic: true do
  describe 'with elasticsearch' do
    before do
      create(:department)
      create(:person, given_name: 'Jon', surname: 'Browne', email: 'jon.browne@digital.justice.gov.uk', primary_phone_number: '0711111111')
      Peoplefinder::Person.import
      sleep 1
      omni_auth_log_in_as 'test.user@digital.justice.gov.uk'
    end

    after do
      clean_up_indexes_and_tables
    end

    scenario 'in the most basic form' do
      visit home_path
      fill_in 'query', with: 'Browne'
      click_button 'Search'
      expect(page).to have_text('> Search results')
      expect(page).to have_text('Jon Browne')
      expect(page).to have_text('jon.browne@digital.justice.gov.uk')
      expect(page).to have_text('0711111111')
      expect(page).to have_link('add them', href: new_person_path)
    end
  end
end
