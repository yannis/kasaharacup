if Rails.env.production?
  AssetSync.configure do |config|
    config.fog_provider = ENV['fog_provider']
    config.aws_access_key_id = ENV['aws_access_key_id']
    config.aws_secret_access_key = ENV['aws_secret_access_key']
    config.fog_directory = ENV['fog_directory']

    # Increase upload performance by configuring your region
    config.fog_region = ENV['fog_region']
    #
    # Don't delete files from the store
    config.existing_remote_files = "ignore"
    #
    # Automatically replace files with their equivalent gzip compressed version
    config.gzip_compression = true
    #
    # Use the Rails generated 'manifest.yml' file to produce the list of files to
    # upload instead of searching the assets directory.
    # config.manifest = true
    #
    # Fail silently.  Useful for environments such as Heroku
    config.fail_silently = true
  end
end
