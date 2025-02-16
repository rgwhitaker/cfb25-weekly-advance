# weekly-advance.rb
require 'discordrb'
require_relative 'config'
require_relative 'commands'

# Hardcoded bot token
bot_token = 'MTM0MDczNTEyNjA4NjM1NzAzMw.GZjn0S.BZVonQancbWFhnGQ1a2zbVBTkSZiw7dq4HLDNo'
bot = Discordrb::Commands::CommandBot.new token: bot_token, prefix: '!'

register_commands(bot)

bot.run
