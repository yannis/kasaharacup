# frozen_string_literal: true

require "rails_helper"

# The matchers under test live in spec/support/custom_matchers.rb. They are only
# ever seen when an example fails, so their failure messages need a spec of
# their own: a wrong message here misleads every model spec in the suite.
RSpec.describe "custom matchers" do # rubocop:disable RSpec/DescribeClass
  let(:model_class) do
    Class.new do
      include ActiveModel::Model

      def self.name = "Duck"

      def self.to_s = name

      attr_accessor :name, :sound

      validates :name, presence: true
      validates :sound, inclusion: {in: %w[quack]}
    end
  end
  let(:invalid_model) { model_class.new(sound: "moo") }
  let(:valid_model) { model_class.new(name: "Donald", sound: "quack") }

  describe "be_valid_verbose" do
    it "lists the validation errors when the record is expected to be valid but is not" do
      matcher = be_valid_verbose

      expect(matcher.matches?(invalid_model)).to be false
      expect(matcher.failure_message).to eq(
        "Duck expected to be valid but had errors:\n #{invalid_model.errors.full_messages.join(". ")}"
      )
      expect(matcher.failure_message).to include(invalid_model.errors.full_messages.first)
    end

    it "reports the absence of errors when the record is expected to be invalid but is not" do
      matcher = be_valid_verbose

      expect(matcher.matches?(valid_model)).to be true
      expect(matcher.failure_message_when_negated).to eq("Duck expected to have errors, but it did not")
    end
  end

  describe "have_errors_on" do
    it "reports the missing error when the attribute is expected to have one" do
      matcher = have_errors_on(:name)

      expect(matcher.matches?(valid_model)).to be false
      expect(matcher.failure_message).to eq("Duck should have errors on attribute :name")
    end

    it "reports the missing message when the attribute is expected to have a specific one" do
      matcher = have_errors_on(:sound).with_message("must be a moo")

      expect(matcher.matches?(invalid_model)).to be false
      expect(matcher.failure_message).to eq(
        "Validation errors #{invalid_model.errors[:sound].inspect} should include \"must be a moo\""
      )
    end

    it "reports the unexpected error when the attribute is expected not to have one" do
      matcher = have_errors_on(:name)

      expect(matcher.matches?(invalid_model)).to be true
      expect(matcher.failure_message_when_negated).to eq("Duck should not have an error on attribute :name")
    end
  end

  describe "act_as_fighter" do
    let(:fighter_class) do
      Class.new do
        def self.name = "Fighter"

        def self.to_s = name

        def win_fight = true
      end
    end
    let(:pacifist_class) do
      Class.new do
        def self.name = "Pacifist"

        def self.to_s = name
      end
    end

    it "reports the missing behaviour when the object is expected to act as a fighter" do
      matcher = act_as_fighter

      expect(matcher.matches?(pacifist_class.new)).to be false
      expect(matcher.failure_message).to eq("Pacifist expected to act_as_fighter but it did not")
    end

    it "reports the unexpected behaviour when the object is expected not to act as a fighter" do
      matcher = act_as_fighter

      expect(matcher.matches?(fighter_class.new)).to be true
      expect(matcher.failure_message_when_negated).to eq("Fighter not expected to act_as_fighter, but it did")
    end
  end
end
