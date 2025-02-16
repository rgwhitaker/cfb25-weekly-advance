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

# URLs for the images
trophy_image_url = 'https://th.bing.com/th/id/OIP.nAcdTDznBgncq5df6MocPwAAAA?rs=1&pid=ImgDetMain'
embed_image_url = 'https://www.operationsports.com/wp-content/uploads/2024/02/IMG_4609.jpeg'

# Footer text and icon URL
footer_text = "2024 Florida Gators | 2025 Florida Gators | 2027 Arizona State Sun Devils"

# Helper function to calculate advance time while skipping Saturdays
def calculate_advance_time(start_time, duration_in_hours)
  advance_time = start_time + (duration_in_hours.to_i * 60 * 60)
  while advance_time.saturday?
    advance_time += 1.day
  end
  advance_time
end

# Helper function to create embed messages
def create_embed(title, description, color, image_url, footer_text, footer_icon_url)
  embed = Discordrb::Webhooks::Embed.new(
    title: title,
    description: description,
    color: color,
    image: Discordrb::Webhooks::EmbedImage.new(url: image_url)
  )
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(
    text: footer_text,
    icon_url: footer_icon_url
  )
  embed
end

# Command to advance the week
bot.command :advance_week do |event, duration_in_hours = '48'|
  week_advances_channel = event.server.channels.find { |c| c.name == 'week-advances' }
  unless week_advances_channel
    event.respond "The 'week-advances' channel was not found."
    next
  end

  current_week_name = weeks[current_week_index]
  current_time = Time.now.in_time_zone('Eastern Time (US & Canada)')
  advance_time = calculate_advance_time(current_time, duration_in_hours)
  advance_time_str = advance_time.strftime('%A, %I:%M %p %Z')
  current_week_index = (current_week_index + 1) % weeks.length

  store.transaction do
    store[:current_week_index] = current_week_index
    store[:current_deadline] = advance_time_str
  end

  next_week_name = weeks[current_week_index]
  description = "🏈 The deadline to complete your recruiting and games is #{advance_time_str}. 🏈"
  embed = create_embed("#{next_week_name} has started!", description, 0x00FF00, embed_image_url,
                       footer_text, trophy_image_url)

  begin
    week_advances_channel.send_message("@everyone")
    week_advances_channel.send_embed('', embed)
  rescue Discordrb::Errors::NoPermission
    event.respond "I don't have permission to send messages to the 'week-advances' channel. Please check my permissions."
  end
end

# Command to set the current week manually
bot.command :set_week do |event, week|
  if week =~ /^\d+$/
    week_number = week.to_i
    if week_number < 1 || week_number > weeks.length
      event.respond "Invalid week number. Please provide a number between 1 and #{weeks.length}."
      next
    end
    current_week_index = week_number - 1
  else
    week_index = weeks.index { |w| w.casecmp(week).zero? }
    if week_index.nil?
      event.respond "Invalid week name. Please provide a valid week name or number."
      next
    end
    current_week_index = week_index
  end

  store.transaction do
    store[:current_week_index] = current_week_index
  end

  current_week_name = weeks[current_week_index]
  description = "🏈 The current week is now #{current_week_name}. 🏈"
  embed = create_embed("Week has been set!", description, 0xFF4500, embed_image_url,
                       footer_text, trophy_image_url)

  event.channel.send_embed('', embed)
end

# Command to show the current week and deadline
bot.command :current_week do |event|
  current_week_name = weeks[current_week_index]
  current_deadline = store.transaction { store[:current_deadline] }
  description = "🏈 The deadline to complete your recruiting and games is #{current_deadline}. 🏈"
  embed = create_embed("Current Week: #{current_week_name}", description, 0x0000FF, embed_image_url,
                       footer_text, trophy_image_url)

  event.channel.send_embed('', embed)
end

bot.run
