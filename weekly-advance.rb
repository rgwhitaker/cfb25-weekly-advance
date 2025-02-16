require 'discordrb'
require 'time'
require 'yaml/store'

# Define the list of possible weeks
weeks = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8", "Week 9", "Week 10",
         "Week 11", "Week 12", "Week 13", "Week 14", "Week 15", "Week 16", "Conference Championships",
         "Bowl Week 1", "Bowl Week 2", "Bowl Week 3", "Bowl Week 4"]

# Initialize data store for persistence
store = YAML::Store.new("week_data.yml")

# Load current week index from the store, or initialize to 0
current_week_index = store.transaction { store[:current_week_index] } || 0
current_deadline = store.transaction { store[:current_deadline] }

# Hardcoded bot token
bot_token = 'MTM0MDczNTEyNjA4NjM1NzAzMw.GZjn0S.BZVonQancbWFhnGQ1a2zbVBTkSZiw7dq4HLDNo'

bot = Discordrb::Commands::CommandBot.new token: bot_token, prefix: '!'

# Command to advance the week
bot.command :advance_week do |event, duration_in_hours = '48'|
  # Ensure only admins can use this command
  unless event.user.permission?(:administrator)
    event.respond "You do not have permission to use this command."
    next
  end

  # Get the current week name
  current_week_name = weeks[current_week_index]

  # Calculate the advance time (current time + duration_in_hours)
  current_time = Time.now
  advance_time = current_time + (duration_in_hours.to_i * 60 * 60)  # Duration in seconds
  advance_time_str = advance_time.strftime('%A, %I:%M %p')  # Format as Day, time in AM/PM

  # Increment the week index
  current_week_index = (current_week_index + 1) % weeks.length

  # Get the next week name for confirmation
  next_week_name = weeks[current_week_index]

  # Store the new week index and deadline persistently
  store.transaction do
    store[:current_week_index] = current_week_index
    store[:current_deadline] = advance_time_str
  end

  # Create the notification message
  message = "The week \"#{current_week_name}\" has been advanced! The deadline to complete your games is #{advance_time_str}.\nThe week has been successfully advanced to \"#{next_week_name}\" with a deadline of #{advance_time_str}."

  # Send the notification message to the channel
  event.respond message
end

# Command to show the current week and deadline
bot.command :current_week do |event|
  current_week_name = weeks[current_week_index]
  current_deadline = store.transaction { store[:current_deadline] }
  event.respond "The current week is \"#{current_week_name}\". The deadline to complete your games is #{current_deadline}."
end

bot.run
