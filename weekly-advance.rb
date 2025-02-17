require 'discordrb'
require_relative 'config'
require_relative 'commands'
require_relative 's3_store' # S3 class for S3 integration
require 'dotenv'
Dotenv.load

# Use Heroku environment variables
S3_BUCKET = ENV['S3_BUCKET_NAME']
S3_REGION = ENV['AWS_REGION']
STORE_OBJECT_KEY = 'store.yml' # The key in the S3 bucket

# Initialize the S3Store with minimal configuration
STORE = S3Store.new(S3_BUCKET, S3_REGION)

bot_token = ENV['DISCORD_BOT_TOKEN']
bot = Discordrb::Commands::CommandBot.new token: bot_token, prefix: '!'

# Ensure the S3 configuration works when the bot is ready
bot.ready do
  existing_data = STORE.get_object(STORE_OBJECT_KEY)
  if existing_data
    puts "[INFO] Loaded existing S3 data: #{existing_data}"
  else
    STORE.put_object(STORE_OBJECT_KEY, {}.to_yaml)
    puts "[INFO] Created initial S3 data store in bucket."
  end
end

register_commands(bot)

bot.run