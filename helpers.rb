# helpers.rb
require 'discordrb'
require 'date'
require 'time'


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

# Helper function to get or reuse the week message
def get_or_create_week_message(event, store)
  channel = event.server.channels.find { |ch| ch.name == 'week-advances' }
  return nil unless channel

  saved_message_id = STORE.transaction { STORE[:message_id] }

  # Debug: Validate saved message ID
  puts "[DEBUG] Retrieved saved_message_id: #{saved_message_id.inspect}"

  if saved_message_id
    begin
      # Attempt to fetch the existing message
      message = channel.message(saved_message_id)

      # Debug: Validate the fetched message
      puts "[DEBUG] Successfully found message with ID: #{saved_message_id}"

      return message
    rescue Discordrb::Errors::NoPermission, Discordrb::Errors::UnknownMessage
      # If permission was denied or the message was deleted, log it
      puts "[DEBUG] Couldn't fetch message with ID: #{saved_message_id} - Creating a new message."
    end
  end

  # Create a new message if no valid saved message exists
  embed = create_default_week_embed

  # Debug: Validate embed before sending
  puts "[DEBUG] Sending new embed message: #{embed.inspect}"

  # Correct positional arguments for `send_message`
  message = channel.send_message('', false, embed)

  STORE.transaction do
    STORE[:message_id] = message.id # Save the new message ID
    # Debug: Confirm message ID is saved
    puts "[DEBUG] New message ID saved: #{message.id}"
  end

  message
end

def send_lobby_notification(server, content)
  # Replace 'lobby' with the actual lobby channel name
  lobby_channel = server.channels.find { |channel| channel.name == 'lobby' }
  return unless lobby_channel

  # Send the ping message to the lobby channel
  lobby_channel.send_message(content, false) # Set tts explicitly to false
end

def message_link(guild_id, channel_id, message_id)
  "https://discord.com/channels/#{guild_id}/#{channel_id}/#{message_id}"
end

# Helper to resolve next occurrence of a specific day (e.g., "Tuesday")
def next_weekday(day_name)
  current_time = Time.now
  target_day = Date::DAYNAMES.find_index(day_name.capitalize)
  return nil unless target_day

  days_ahead = (target_day - current_time.wday) % 7
  days_ahead = 7 if days_ahead == 0 # If today is the target day, move it to the next week
  current_time + (days_ahead * 24 * 60 * 60) # Add days in seconds
end

# Helper function to create the default embed for the week message
def create_default_week_embed
  title = "Welcome to the New Week!"
  description = "🏈 A new week has begun! Complete your recruiting and games before the deadline. 🏈"
  color = 0x00FF00 # Green color
  image_url = "https://example.com/placeholder-image.png" # Replace with your embed image URL
  footer_text = "League Updates"
  footer_icon_url = "https://example.com/placeholder-footer-icon.png" # Replace with your footer icon URL

  embed = create_embed(title, description, color, image_url, footer_text, footer_icon_url)

  # Debug: Inspect the embed object
  puts "[DEBUG] Created default embed: #{embed.inspect}"

  embed
end
