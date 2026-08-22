# frozen_string_literal: true

require "rails_helper"

RSpec.describe KenshisController do
  def valid_params
    {last_name: "a_last_name", female: false, first_name: "a_first_name", grade: "1Dan", club_name: "a_club", cup:,
     dob: 20.years.ago}
  end

  before {
    travel_to(cup.deadline - 5.days)
  }

  describe "with 3 kenshis in the database," do
    let!(:cup) { create(:cup, start_on: Date.parse("#{Date.current.year}-11-30")) }
    let!(:individual_category) { create(:individual_category, cup:) }
    let(:user) { create(:user) }
    let(:user2) { create(:user, admin: true) }
    let!(:kenshi1) { create(:kenshi, last_name: "kenshi1", user_id: user.to_param, cup:) }
    let!(:participation1) { create(:participation, kenshi: kenshi1, category: individual_category) }
    let!(:kenshi2) { create(:kenshi, last_name: "kenshi2", user_id: user2.to_param, cup:) }
    let!(:kenshi3) { create(:kenshi, last_name: "kenshi3", user_id: user.to_param, cup:) }
    let!(:participation3) { create(:participation, kenshi: kenshi3, category: individual_category) }

    context "when not logged in," do
      describe "on GET to :index" do
        before do
          get(cup_kenshis_path(cup))
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:kenshis)).not_to be_nil }
        it { expect(response).to render_template(:index) }
        it { expect(assigns(:kenshis)).to contain_exactly(kenshi1, kenshi3) }
        it { expect(flash).to be_empty }
      end

      describe "when GET to :show for kenshi1.id," do
        before { get(cup_kenshi_path(cup, kenshi1)) }

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:kenshi)).to eql kenshi1 }
        it { expect(response).to render_template(:show) }
        it { expect(flash).to be_empty }
      end

      describe "on get(new_cup_kenshi_path(cup))" do
        before do
          get(new_cup_kenshi_path(cup))
        end

        it { should_be_asked_to_sign_in } # rubocop:disable RSpec/NoExpectationExample
      end

      describe "on post(cup_kenshis_path(cup), params: {kenshi: {last_name: 'just created kenshi'}})" do
        before do
          post(cup_kenshis_path(cup), params: {kenshi: {last_name: "just created kenshi"}})
        end

        it { should_be_asked_to_sign_in } # rubocop:disable RSpec/NoExpectationExample
      end

      describe "on put(cup_kenshi_path(cup, kenshi1), params: {kenshi: {last_name: 'just updated kenshi'}})" do
        before do
          put(cup_kenshi_path(cup, kenshi1), params: {kenshi: {last_name: "just updated kenshi"}})
        end

        it { should_be_asked_to_sign_in } # rubocop:disable RSpec/NoExpectationExample
      end

      describe "on delete(cup_kenshi_path(cup, kenshi1))" do
        before do
          delete(cup_kenshi_path(cup, kenshi1))
        end

        it { should_be_asked_to_sign_in } # rubocop:disable RSpec/NoExpectationExample
      end
    end

    describe "when logged in" do
      let(:basic_user) { create(:user) }
      let(:basic_user_kenshi) { create(:kenshi, user_id: basic_user.id, cup:) }

      before { sign_in basic_user }

      describe "on GET to :index without param," do
        before do
          get(cup_kenshis_path(cup))
        end

        it { expect(assigns(:kenshis)).not_to be_nil }
        it { expect(response).to render_template(:index) }
        it { expect(assigns(:kenshis)).to contain_exactly(kenshi1, kenshi3) }
        it { expect(flash).to be_empty }
      end

      describe "when GET to :show for kenshi1.id," do
        before { get(cup_kenshi_path(cup, kenshi1)) }

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:kenshi)).not_to be_nil }
        it { expect(response).to render_template(:show) }
        it { expect(flash).to be_empty }
        it { expect(assigns(:kenshi)).to eql kenshi1 }
      end

      describe "when GET to :new with user_id: basic_user.to_param," do
        before { get(new_cup_user_kenshi_path(cup)) }

        it { expect(assigns(:current_user)).to eql basic_user }
        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:kenshi)).not_to be_nil }
        it { expect(response).to render_template(:new) }
        it { expect(flash).to be_empty }
      end

      describe "when POST to :create with valid data," do
        before { post(cup_user_kenshis_path(cup), params: {kenshi: valid_params.merge(terms_acceptance: "1")}) }

        it { expect(assigns(:kenshi)).to be_an_instance_of Kenshi }
        it { expect(assigns(:kenshi)).to be_valid_verbose }
        it { expect(response).to redirect_to(cup_user_path(cup)) }
        it { expect(flash[:notice]).to include("Kenshi inscrit avec succès") }
        it { expect(assigns(:kenshi).user_id).to eql basic_user.id }
        it { expect(assigns(:kenshi).terms_accepted_at).to be_within(5.seconds).of(Time.current) }
      end

      describe "terms acceptance" do
        describe "on POST to :create with an unticked checkbox," do
          it "does not create the kenshi and re-renders the form" do
            expect {
              post(cup_user_kenshis_path(cup), params: {kenshi: valid_params.merge(terms_acceptance: "0")})
            }.not_to change(Kenshi, :count)

            expect(response).to have_http_status(:unprocessable_content)
            expect(response).to render_template(:new)
          end
        end

        describe "on POST to :create omitting the acceptance param entirely," do
          it "does not create the kenshi" do
            expect {
              post(cup_user_kenshis_path(cup), params: {kenshi: valid_params})
            }.not_to change(Kenshi, :count)

            expect(response).to have_http_status(:unprocessable_content)
          end
        end

        describe "on POST to :create with tampered acceptance fields," do
          it "stamps the server time and ignores the submitted timestamp and gate" do
            post(cup_user_kenshis_path(cup), params: {kenshi: valid_params.merge(
              terms_acceptance: "1",
              terms_accepted_at: 10.years.ago.iso8601,
              terms_acceptance_required: "0"
            )})

            expect(assigns(:kenshi)).to be_persisted
            expect(assigns(:kenshi).terms_accepted_at).to be_within(5.seconds).of(Time.current)
          end
        end

        describe "on GET to :new," do
          it "renders a required acceptance checkbox linking to the terms page" do
            get(new_cup_user_kenshi_path(cup))

            expect(response.body).to include("kenshi[terms_acceptance]")
            expect(response.body).to include(cup_terms_path(cup))
          end
        end

        describe "on GET to :edit," do
          it "renders no acceptance checkbox" do
            get(edit_cup_kenshi_path(cup, basic_user_kenshi))

            expect(response.body).not_to include("kenshi[terms_acceptance]")
          end
        end

        describe "on PUT to :update," do
          it "does not require re-acceptance and keeps the original stamp" do
            accepted = create(:kenshi, user_id: basic_user.id, cup:,
              terms_acceptance_required: true, terms_acceptance: "1")
            original = accepted.terms_accepted_at

            put(cup_kenshi_path(cup, accepted), params: {kenshi: {last_name: "Updated"}})

            expect(response).to redirect_to(cup_user_path(cup))
            expect(accepted.reload.terms_accepted_at).to be_within(1.second).of(original)
          end
        end

        describe "on GET to :duplicate," do
          it "clears the source's acceptance stamp and re-requires acceptance" do
            source = create(:kenshi, user_id: basic_user.id, cup:)
            Kenshi.where(id: source.id).update_all(terms_accepted_at: 2.years.ago)

            get(duplicate_cup_user_kenshi_path(cup, source))

            expect(assigns(:kenshi).terms_accepted_at).to be_nil
            expect(response.body).to include("kenshi[terms_acceptance]")
          end
        end
      end

      describe "when POST to :create with invalid data," do
        before { post(cup_user_kenshis_path(cup), params: {kenshi: {last_name: ""}}) }

        it { expect(assigns(:kenshi)).not_to be_nil }
        it { expect(assigns(:kenshi)).to be_an_instance_of Kenshi }
        it { expect(assigns(:kenshi)).not_to be_valid_verbose }
        it { expect(response).to render_template(:new) }
        it { expect(flash.now[:alert]).to include("Erreur lors de l'inscription du kenshi") }
      end

      describe "on GET to :edit with :id = basic_user_kenshi.to_param," do
        before { get(edit_cup_kenshi_path(cup, basic_user_kenshi)) }

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:kenshi)).to eql basic_user_kenshi }
        it { expect(response).to render_template(:edit) }
      end

      describe "on GET to :edit with :id = kenshi1.to_param," do
        before { get(edit_cup_kenshi_path(cup, kenshi1)) }

        it { should_not_be_authorized } # rubocop:disable RSpec/NoExpectationExample
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data" do
        before { put(cup_kenshi_path(cup, basic_user_kenshi), params: {kenshi: {last_name: "alaNma2"}}) }

        it { expect(assigns(:kenshi)).to eql basic_user_kenshi }
        it { expect(response).to redirect_to(cup_user_path(cup)) }
        it { expect(flash[:notice]).to include("Inscription modifiée avec succès") }
        it { expect(basic_user_kenshi.reload.last_name).to eql "Alanma2" }
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and invalid data," do
        before { put(cup_kenshi_path(cup, basic_user_kenshi), params: {kenshi: {last_name: ""}}) }

        it { expect(assigns(:kenshi)).to eql basic_user_kenshi }
        it { expect(response).to render_template(:edit) }
      end

      describe "on PUT to :update with :id = kenshi1.to_param and valid data," do
        before { put cup_kenshi_path(cup, kenshi1), params: {kenshi: {last_name: "alaNma2"}} }

        it { should_not_be_authorized } # rubocop:disable RSpec/NoExpectationExample
      end

      describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
        before {
          basic_user_kenshi.save
        }

        it do
          expect { delete(cup_kenshi_path(cup, basic_user_kenshi)) }
            .to change(Kenshi, :count).by(-1)
          expect(assigns(:kenshi)).to eql basic_user_kenshi
          expect(flash[:notice]).to include("Kenshi détruit avec succès")
          expect(response).to redirect_to(cup_user_path(cup))
        end
      end

      describe "on DELETE to :destroy with :id = kenshi1.to_param," do
        before { delete(cup_kenshi_path(cup, kenshi1)) }

        it { should_not_be_authorized } # rubocop:disable RSpec/NoExpectationExample
      end

      context "when deadline is passed" do
        before {
          travel_to(cup.deadline + 5.minutes)
        }

        describe "when GET to :new with user_id: basic_user.to_param," do
          before { get(new_cup_user_kenshi_path(cup)) }

          it { has_passed_deadline } # rubocop:disable RSpec/NoExpectationExample
        end

        describe "on GET to :edit with :id = basic_user_kenshi.to_param," do
          before { get(edit_cup_kenshi_path(cup, basic_user_kenshi)) }

          it { has_passed_deadline } # rubocop:disable RSpec/NoExpectationExample
        end

        describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data," do
          before { put(cup_kenshi_path(cup, basic_user_kenshi), params: {kenshi: {last_name: "AlaNma2"}}) }

          it { has_passed_deadline } # rubocop:disable RSpec/NoExpectationExample
        end

        describe "when POST to :create with valid data," do
          before { post(cup_kenshis_path(cup), params: {kenshi: valid_params}) }

          it { has_passed_deadline } # rubocop:disable RSpec/NoExpectationExample
        end

        describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
          before do
            basic_user_kenshi.save
            @kenshi_count = Kenshi.count
            delete(cup_kenshi_path(cup, basic_user_kenshi))
          end

          it { has_passed_deadline } # rubocop:disable RSpec/NoExpectationExample
        end
      end
    end
  end
end
