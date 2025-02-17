# weekly-advance.rb
require 'discordrb'
require_relative 'config'
require_relative 'commands'
require 'dotenv'
Dotenv.load

bot_token = ENV['DISCORD_BOT_TOKEN']
bot = Discordrb::Commands::CommandBot.new token: bot_token, prefix: '!'

register_commands(bot)

bot.run
