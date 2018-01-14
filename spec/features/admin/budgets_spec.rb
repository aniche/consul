require 'rails_helper'

feature 'Admin budgets' do

  background do
    admin = create(:administrator)
    login_as(admin.user)
  end

  context 'Feature flag' do

    background do
      Setting['feature.budgets'] = nil
    end

    after do
      Setting['feature.budgets'] = true
    end

    scenario 'Disabled with a feature flag' do
      expect{ visit admin_budgets_path }.to raise_exception(FeatureFlags::FeatureDisabled)
    end

  end

  context 'Index' do

    scenario 'Displaying budgets' do
      budget = create(:budget)
      visit admin_budgets_path

      expect(page).to have_content(budget.name)
      expect(page).to have_content(I18n.t("budgets.phase.#{budget.phase}"))
    end

    scenario 'Filters by phase' do
      drafting_budget  = create(:budget, :drafting)
      accepting_budget = create(:budget, :accepting)
      selecting_budget = create(:budget, :selecting)
      balloting_budget = create(:budget, :balloting)
      finished_budget  = create(:budget, :finished)

      visit admin_budgets_path
      expect(page).to have_content(drafting_budget.name)
      expect(page).to have_content(accepting_budget.name)
      expect(page).to have_content(selecting_budget.name)
      expect(page).to have_content(balloting_budget.name)
      expect(page).not_to have_content(finished_budget.name)

      click_link 'Finished'
      expect(page).not_to have_content(drafting_budget.name)
      expect(page).not_to have_content(accepting_budget.name)
      expect(page).not_to have_content(selecting_budget.name)
      expect(page).not_to have_content(balloting_budget.name)
      expect(page).to have_content(finished_budget.name)

      click_link 'Open'
      expect(page).to have_content(drafting_budget.name)
      expect(page).to have_content(accepting_budget.name)
      expect(page).to have_content(selecting_budget.name)
      expect(page).to have_content(balloting_budget.name)
      expect(page).not_to have_content(finished_budget.name)
    end

    scenario 'Open filter is properly highlighted' do
      filters_links = {'current' => 'Open', 'finished' => 'Finished'}

      visit admin_budgets_path

      expect(page).not_to have_link(filters_links.values.first)
      filters_links.keys.drop(1).each { |filter| expect(page).to have_link(filters_links[filter]) }

      filters_links.each_pair do |current_filter, link|
        visit admin_budgets_path(filter: current_filter)

        expect(page).not_to have_link(link)

        (filters_links.keys - [current_filter]).each do |filter|
          expect(page).to have_link(filters_links[filter])
        end
      end
    end

  end

  context 'New' do

    scenario 'Create budget' do
      visit admin_budgets_path
      click_link 'Create new budget'

      fill_in 'budget_name', with: 'M30 - Summer campaign'
      fill_in 'budget_description_accepting', with: 'Budgeting for summer 2017 maintenance and improvements of the road M-30'
      select 'Accepting projects', from: 'budget[phase]'

      click_button 'Create Participatory budget'

      expect(page).to have_content 'New participatory budget created successfully!'
      expect(page).to have_content 'M30 - Summer campaign'
    end

    scenario 'Name is mandatory' do
      visit new_admin_budget_path
      click_button 'Create Participatory budget'

      expect(page).not_to have_content 'New participatory budget created successfully!'
      expect(page).to have_css("label.error", text: "Name")
    end

  end

  context 'Destroy' do

    let!(:budget) { create(:budget) }
    let(:heading) { create(:budget_heading, group: create(:budget_group, budget: budget)) }

    scenario 'Destroy a budget without investments' do
      visit admin_budgets_path
      click_link 'Edit budget'
      click_button 'Delete budget'

      expect(page).to have_content('Budget deleted successfully')
      expect(page).to have_content('participatory budgets cannot be found')
    end

    scenario 'Try to destroy a budget with investments' do
      create(:budget_investment, heading: heading)

      visit admin_budgets_path
      click_link 'Edit budget'
      click_button 'Delete budget'

      expect(page).to have_content('You cannot destroy a Budget that has associated investments')
      expect(page).to have_content('There is 1 participatory budget')
    end
  end
  
  context 'Update' do

    background do
      create(:budget)
    end

    scenario 'Update budget' do
      visit admin_budgets_path
      click_link 'Edit budget'

      fill_in 'budget_name', with: 'More trees on the streets'
      click_button 'Update Participatory budget'

      expect(page).to have_content('More trees on the streets')
      expect(page).to have_current_path(admin_budgets_path)
    end

  end

  context "Calculate Budget's Winner Investments" do

    scenario 'For a Budget in reviewing balloting' do
      budget = create(:budget, phase: 'reviewing_ballots')
      group = create(:budget_group, budget: budget)
      heading = create(:budget_heading, group: group, price: 4)
      unselected_investment = create(:budget_investment, :unselected, heading: heading, price: 1, ballot_lines_count: 3)
      winner_investment = create(:budget_investment, :winner, heading: heading, price: 3, ballot_lines_count: 2)
      selected_investment = create(:budget_investment, :selected, heading: heading, price: 2, ballot_lines_count: 1)

      visit edit_admin_budget_path(budget)
      click_link 'Calculate Winner Investments'
      expect(page).to have_content 'Winners being calculated, it may take a minute.'
      expect(page).to have_content winner_investment.title
      expect(page).not_to have_content unselected_investment.title
      expect(page).not_to have_content selected_investment.title
    end

    scenario 'For a finished Budget' do
      budget = create(:budget, phase: 'finished')

      visit edit_admin_budget_path(budget)
      expect(page).not_to have_content 'Calculate Winner Investments'
    end

  end

  context 'Manage groups and headings' do

    scenario 'Create group', :js do
      budget = create(:budget, name: 'Yearly participatory budget')

      visit admin_budgets_path

      within("#budget_#{budget.id}") do
        click_link 'Edit headings groups'
      end

      expect(page).to have_content '0 Groups of budget headings'
      expect(page).to have_content 'No groups created yet.'

      click_link 'Add new group'

      fill_in 'budget_group_name', with: 'Health'
      click_button 'Create group'

      expect(page).to have_content '1 Group of budget headings'
      expect(page).to have_content 'Health'
      expect(page).to have_content 'Yearly participatory budget'
      expect(page).not_to have_content 'No groups created yet.'

      visit admin_budgets_path
      within("#budget_#{budget.id}") do
        click_link 'Edit headings groups'
      end

      expect(page).to have_content '1 Group of budget headings'
      expect(page).to have_content 'Health'
      expect(page).to have_content 'Yearly participatory budget'
      expect(page).not_to have_content 'No groups created yet.'
    end

    scenario 'Create heading', :js do
      budget = create(:budget, name: 'Yearly participatory budget')
      group  = create(:budget_group, budget: budget, name: 'Districts improvments')

      visit admin_budget_path(budget)

      within("#budget_group_#{group.id}") do
        expect(page).to have_content 'This group has no assigned heading.'
        click_link 'Add heading'

        fill_in 'budget_heading_name', with: 'District 9 reconstruction'
        fill_in 'budget_heading_price', with: '6785'
        fill_in 'budget_heading_population', with: '100500'
        click_button 'Save heading'
      end

      expect(page).not_to have_content 'This group has no assigned heading.'

      visit admin_budget_path(budget)
      within("#budget_group_#{group.id}") do
        expect(page).not_to have_content 'This group has no assigned heading.'

        expect(page).to have_content 'District 9 reconstruction'
        expect(page).to have_content '6785'
        expect(page).to have_content '100500'
      end
    end

    scenario 'Update heading', :js do
      budget = create(:budget, name: 'Yearly participatory budget')
      group  = create(:budget_group, budget: budget, name: 'Districts improvments')
      heading = create(:budget_heading, group: group, name: "District 1")
      heading = create(:budget_heading, group: group, name: "District 3")

      visit admin_budget_path(budget)

      within("#heading-#{heading.id}") do
        click_link 'Edit'

        fill_in 'budget_heading_name', with: 'District 2'
        fill_in 'budget_heading_price', with: '10000'
        fill_in 'budget_heading_population', with: '6000'
        click_button 'Save heading'
      end

      expect(page).to have_content 'District 2'
      expect(page).to have_content '10000'
      expect(page).to have_content '6000'
    end

    scenario 'Delete heading', :js do
      budget = create(:budget, name: 'Yearly participatory budget')
      group  = create(:budget_group, budget: budget, name: 'Districts improvments')
      heading = create(:budget_heading, group: group, name: "District 1")

      visit admin_budget_path(budget)

      expect(page).to have_content 'District 1'

      within("#heading-#{heading.id}") do
        click_link 'Delete'
      end

      expect(page).to_not have_content 'District 1'
    end

  end
end
