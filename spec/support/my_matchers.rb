RSpec::Matchers.define :be_valid_verbose do
  match do |model|
    model.valid?
  end

  failure_message do |model|
    "#{model.class} expected to be valid but had errors:n #{model.errors.full_messages.join(". ")}"
  end

  failure_message do |model|
    "#{model.class} expected to have errors, but it did not"
  end

  description do
    "be valid"
  end
end

RSpec::Matchers.define :have_errors_on do |attribute|
  chain :with_message do |message|
    @message = message
  end

  match do |model|
    model.valid?

    @has_errors = model.errors[attribute].present?

    if @message
      @has_errors && model.errors[attribute].include?(@message)
    else
      @has_errors
    end
  end

  failure_message do |model|
    if @message
      "Validation errors #{model.errors[attribute].inspect} should include #{@message.inspect}"
    else
      "#{model.class} should have errors on attribute #{attribute.inspect}"
    end
  end

  failure_message do |model|
    "#{model.class} should not have an error on attribute #{attribute.inspect}"
  end
end


RSpec::Matchers.define :act_as_fighter do

  match do |model|
    model.respond_to?(:win_fight)
  end

  failure_message do |model|
    "#{model.class} expected to act_as_fighter but it did not"
  end

  failure_message do |model|
    "#{model.class} not expected to act_as_fighter, but it did"
  end

  description do
    "act as fighter"
  end
end
