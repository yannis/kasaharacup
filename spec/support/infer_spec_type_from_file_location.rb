# frozen_string_literal: true

# Additional type metadata for non-standard directory mappings
# Copied from: https://github.com/rspec/rspec-rails/blob/b3ebb94cf62a0cb9210ac7f92d50c9be797f7808/lib/rspec/rails/configuration.rb#L146
RSpec.configure do |config|
  {
    %w[spec components] => :component
  }.each do |dir_parts, type|
    escaped_path = Regexp.compile(dir_parts.join("[\\\/]") + "[\\\/]")
    config.define_derived_metadata(file_path: escaped_path) do |metadata|
      metadata[:type] ||= type
    end
  end
end
