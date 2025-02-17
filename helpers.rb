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
  week_advances_channel = event.server.channels.find { |c| c.name == 'week-advances' }
  return nil unless week_advances_channel

  store.transaction do
    week_message_id = store[:week_message_id]
    if week_message_id
      # Try to load the existing message by its ID
      begin
        message = week_advances_channel.load_message(week_message_id)
        return message if message # Return the existing message if found
      rescue Discordrb::Errors::NoPermission, Discordrb::Errors::NotFound
        # If the message cannot be accessed or does not exist, continue to create a new one
        store[:week_message_id] = nil
      end
    end

    # Create a new message if no valid message is found
    new_message = week_advances_channel.send_message("Week advances information will be updated here.")
    store[:week_message_id] = new_message.id
    new_message
  end
end

def send_lobby_notification(server, content)
  # Replace 'lobby' with the actual lobby channel name
  lobby_channel = server.channels.find { |channel| channel.name == 'lobby' }
  return unless lobby_channel

  # Send the ping message to the lobby channel
  lobby_channel.send_message(content)
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
