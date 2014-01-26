
guard 'livereload', :api_version => '2.3' do
  watch(%r{app/.+.(erb|haml)})
  watch(%r{app/helpers/.+.rb})
  watch(%r{app/admin/.+.rb})
  watch(%r{(public/|app/assets).+.(css|js|html)})
  watch(%r{(app/assets).+.(css|js|html)})
  watch(%r{(app/assets/.+.css).s[ac]ss}) { |m| m[1] }
  watch(%r{(app/assets/.+.js).coffee}) { |m| m[1] }
  watch(%r{config/locales/.+.yml})
  watch(%r{^app/assets/.+$})
  watch(%r{^app/presenters/.+$})
  watch(%r{^app/controllers/.+$})
end


guard :rspec,  cmd: "zeus rspec --profile --color -f progress", all_after_pass: true, all_on_start: true do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

  # Rails example
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml|\.slim)$})          { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/acceptance/#{m[1]}_spec.rb"] }
  watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
  watch('config/routes.rb')                           { "spec/routing" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }

  # Capybara features specs
  watch(%r{^app/views/(.+)/.*\.(erb|haml|slim)$})     { |m| "spec/features/#{m[1]}_spec.rb" }

  # Turnip features and steps
  watch(%r{^spec/acceptance/(.+)\.feature$})
  watch(%r{^spec/acceptance/steps/(.+)_steps\.rb$})   { |m| Dir[File.join("**/#{m[1]}.feature")][0] || 'spec/acceptance' }
end


guard 'bundler' do
  watch('Gemfile')
  # Uncomment next line if Gemfile contain `gemspec' command
  # watch(/^.+\.gemspec/)
end
