require 'discordrb'
require 'time'
require 'yaml/store'
require 'active_support/time'

# Define the list of possible weeks
weeks = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8", "Week 9", "Week 10",
         "Week 11", "Week 12", "Week 13", "Week 14", "Week 15", "Week 16", "Conference Championships",
         "Bowl Week 1", "Bowl Week 2", "Bowl Week 3", "Bowl Week 4", "Position Changes"]

# Initialize data store for persistence
store = YAML::Store.new("week_data.yml")

# Load current week index from the store, or initialize to 0
current_week_index = store.transaction { store[:current_week_index] } || 0
current_deadline = store.transaction { store[:current_deadline] }

# Hardcoded bot token
bot_token = 'MTM0MDczNTEyNjA4NjM1NzAzMw.GZjn0S.BZVonQancbWFhnGQ1a2zbVBTkSZiw7dq4HLDNo'

bot = Discordrb::Commands::CommandBot.new token: bot_token, prefix: '!'

# Helper function to calculate advance time while skipping Saturdays
def calculate_advance_time(start_time, duration_in_hours)
  advance_time = start_time + (duration_in_hours.to_i * 60 * 60)
  while advance_time.saturday?
    advance_time += 1.day
  end
  advance_time
end

# URL for the national championship trophy image
trophy_image_url = 'https://th.bing.com/th/id/OIP.nAcdTDznBgncq5df6MocPwAAAA?rs=1&pid=ImgDetMain'
# URL for the embed image
embed_image_url = 'https://www.operationsports.com/wp-content/uploads/2024/02/IMG_4609.jpeg'

# Command to advance the week
bot.command :advance_week do |event, duration_in_hours = '48'|
  # Ensure the message is posted in the "week-advances" channel
  week_advances_channel = event.server.channels.find { |c| c.name == 'week-advances' }
  unless week_advances_channel
    event.respond "The 'week-advances' channel was not found."
    next
  end

  # Get the current week name
  current_week_name = weeks[current_week_index]

  # Calculate the advance time (current time + duration_in_hours)
  current_time = Time.now.in_time_zone('Eastern Time (US & Canada)')
  advance_time = calculate_advance_time(current_time, duration_in_hours)
  advance_time_str = advance_time.strftime('%A, %I:%M %p %Z')  # Format as Day, time in AM/PM with timezone

  # Increment the week index
  current_week_index = (current_week_index + 1) % weeks.length

  # Store the new week index and deadline persistently
  store.transaction do
    store[:current_week_index] = current_week_index
    store[:current_deadline] = advance_time_str
  end

  # Get the next week name for the next advance
  next_week_name = weeks[current_week_index]

  # Create the embed message with football emojis, footer, and image
  embed = Discordrb::Webhooks::Embed.new(
    title: "#{next_week_name} has started!",
    description: "🏈 The deadline to complete your recruiting and games is #{advance_time_str}. 🏈",
    color: 0x00FF00, # Green color
    image: Discordrb::Webhooks::EmbedImage.new(url: embed_image_url)
  )
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(
    text: "2024 Florida Gators | 2025 Florida Gators | 2027 Arizona State Sun Devils",
    icon_url: trophy_image_url
  )

  # Send the embed message to the "week-advances" channel and tag @everyone
  begin
    week_advances_channel.send_message("@everyone")
    week_advances_channel.send_embed('', embed)
  rescue Discordrb::Errors::NoPermission
    event.respond "I don't have permission to send messages to the 'week-advances' channel."
  end
end

# Command to set the current week manually
bot.command :set_week do |event, week|
  # Check if the input is a number
  if week =~ /^\d+$/
    week_number = week.to_i
    if week_number < 1 || week_number > weeks.length
      event.respond "Invalid week number. Please provide a number between 1 and #{weeks.length}."
      next
    end
    current_week_index = week_number - 1
  else
    # Check if the input is a valid week name
    week_index = weeks.index { |w| w.casecmp(week).zero? }
    if week_index.nil?
      event.respond "Invalid week name. Please provide a valid week name or number."
      next
    end
    current_week_index = week_index
  end

  # Store the new week index persistently
  store.transaction do
    store[:current_week_index] = current_week_index
  end

  # Get the current week name
  current_week_name = weeks[current_week_index]

  # Create the embed message with football emojis, footer, and image
  embed = Discordrb::Webhooks::Embed.new(
    title: "Week has been set!",
    description: "🏈 The current week is now #{current_week_name}. 🏈",
    color: 0xFF4500, # Orange color
    image: Discordrb::Webhooks::EmbedImage.new(url: embed_image_url)
  )
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(
    text: "2024 Florida Gators | 2025 Florida Gators | 2027 Arizona State Sun Devils",
    icon_url: trophy_image_url
  )

  # Send the embed message to the channel where the command was run
  event.channel.send_embed('', embed)
end

# Command to show the current week and deadline
bot.command :current_week do |event|
  current_week_name = weeks[current_week_index]
  current_deadline = store.transaction { store[:current_deadline] }

  # Create the embed message with football emojis, footer, and image
  embed = Discordrb::Webhooks::Embed.new(
    title: "Current Week: #{current_week_name}",
    description: "🏈 The deadline to complete your recruiting and games is #{current_deadline}. 🏈",
    color: 0x0000FF, # Blue color
    image: Discordrb::Webhooks::EmbedImage.new(url: embed_image_url)
  )
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(
    text: "2024 Florida Gators | 2025 Florida Gators | 2027 Arizona State Sun Devils",
    icon_url: trophy_image_url
  )

  # Send the embed message to the channel where the command was run
  event.channel.send_embed('', embed)
end

bot.run
