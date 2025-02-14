require 'discordrb'
require 'time'

# Define the list of possible weeks
weeks = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8", "Week 9", "Week 10",
         "Week 11", "Week 12", "Week 13", "Week 14", "Week 15", "Week 16", "Conference Championships", 
         "Bowl Week 1", "Bowl Week 2", "Bowl Week 3", "Bowl Week 4"]

# Initialize the current week index
current_week_index = 0

bot = Discordrb::Commands::CommandBot.new token: 'BOT_TOKEN', prefix: '!'

bot.command :advance_week do |event|
  # Get the current week name
  current_week_name = weeks[current_week_index]

  # Calculate the advance time (current time + 48 hours)
  current_time = Time.now
  advance_time = current_time + (48 * 60 * 60)  # 48 hours in seconds
  advance_time_str = advance_time.strftime('%Y-%m-%d %H:%M:%S')

  # Create the notification message
  message = "The week \"#{current_week_name}\" has been advanced! The deadline to complete your games is #{advance_time_str}."

  # Send the notification message to the channel
  event.respond message

  # Increment the week index
  current_week_index = (current_week_index + 1) % weeks.length  # Wrap around to the first week if we reach the end
end

bot.run
