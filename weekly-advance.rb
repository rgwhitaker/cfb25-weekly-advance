# weekly-advance.rb
require 'discordrb'
require_relative 'config'
require_relative 'commands'
require_relative 'yaml_store'
require 'dotenv'
Dotenv.load

# Set up persistent YAML store
STORE_PATH = 'store.yml' # File to store persistent data
STORE = YamlStore.new(STORE_PATH)

bot_token = ENV['DISCORD_BOT_TOKEN']
bot = Discordrb::Commands::CommandBot.new token: bot_token, prefix: '!'

register_commands(bot)

bot.run
