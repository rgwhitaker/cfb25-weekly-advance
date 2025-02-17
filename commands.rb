# commands.rb
require 'active_support/time'
require_relative 'config'
require_relative 'helpers'

def format_deadline(deadline_str)
  deadline = Time.parse(deadline_str).in_time_zone('Eastern Time (US & Canada)')
  deadline.strftime('%A at %I:%M %p')
end

def register_commands(bot)
  # Command to advance the week
  bot.command :advance_week do |event, duration_in_hours = '48'|
    message = get_or_create_week_message(event, STORE)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create the message."
      next
    end

    current_week_index = STORE.transaction { STORE[:current_week_index] } || 0
    current_week_name = WEEKS[current_week_index]
    current_time = Time.now.in_time_zone('Eastern Time (US & Canada)')
    advance_time = calculate_advance_time(current_time, duration_in_hours)
    advance_time_str = format_deadline(advance_time.to_s)
    current_week_index = (current_week_index + 1) % WEEKS.length

    STORE.transaction do
      STORE[:current_week_index] = current_week_index
      STORE[:current_deadline] = advance_time_str
    end

    next_week_name = WEEKS[current_week_index]
    description = "🏈 The deadline to complete your recruiting and games is #{advance_time_str}. 🏈"
    embed = create_embed("#{next_week_name} has started!", description, 0x00FF00, EMBED_IMAGE_URL,
                         FOOTER_TEXT, TROPHY_IMAGE_URL)

    begin
      # Update the persistent embed in the week-advances channel
      message.edit('', embed)
      event.respond "Week advanced to #{next_week_name}, and the deadline is set to #{advance_time_str}."

      # Construct the message link
      link = message_link(event.server.id, message.channel.id, message.id)

      # Send a ping to the lobby channel
      ping_message = "📢 @everyone, the **week has advanced** to **#{next_week_name}**! 🏈\nDeadline: **#{advance_time_str}**.\nView the full announcement here: [Click to view](#{link})"
      send_lobby_notification(event.server, ping_message)
    rescue Discordrb::Errors::NoPermission
      event.respond "I don't have permission to edit messages in the 'week-advances' channel. Please check my permissions."
    end
  end

  # Command to set the current week manually
  bot.command :set_week do |event, week|
    message = get_or_create_week_message(event, STORE)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create the message."
      next
    end

    current_week_index = STORE.transaction { STORE[:current_week_index] } || 0

    if week =~ /^\d+$/
      week_number = week.to_i
      if week_number < 1 || week_number > WEEKS.length
        event.respond "Invalid week number. Please provide a number between 1 and #{WEEKS.length}."
        next
      end
      current_week_index = week_number - 1
    else
      week_index = WEEKS.index { |w| w.casecmp(week).zero? }
      if week_index.nil?
        event.respond "Invalid week name. Please provide a valid week name or number."
        next
      end
      current_week_index = week_index
    end

    STORE.transaction do
      STORE[:current_week_index] = current_week_index
    end

    current_week_name = WEEKS[current_week_index]
    current_deadline = STORE.transaction { STORE[:current_deadline] }
    formatted_deadline = format_deadline(current_deadline)

    begin
      # Update the persistent embed
      original_embed = message.embeds.first
      new_title = "#{current_week_name} has started!"
      new_description = "🏈 The deadline to complete your recruiting and games is #{formatted_deadline}. 🏈"

      embed = create_embed(new_title, new_description, original_embed.color || 0x00FF00, EMBED_IMAGE_URL,
                           FOOTER_TEXT, TROPHY_IMAGE_URL)
      message.edit('', embed)

      event.respond "Current week set to #{current_week_name} (#{formatted_deadline})."

      # Construct the message link
      link = message_link(event.server.id, message.channel.id, message.id)

      # Send a ping to the lobby channel
      ping_message = "📢 @everyone, the **current week** has been manually set to **#{current_week_name}**! 🏈\nDeadline: **#{formatted_deadline}**.\nView the full announcement here: [Click to view](#{link})"
      send_lobby_notification(event.server, ping_message)
    rescue Discordrb::Errors::NoPermission
      event.respond "I don't have permission to edit messages in the 'week-advances' channel. Please check my permissions."
    end
  end

  # Command to set the deadline manually
  bot.command :set_deadline do |event, new_deadline|
    message = get_or_create_week_message(event, STORE)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create the message."
      next
    end

    STORE.transaction do
      STORE[:current_deadline] = new_deadline
    end

    current_week_index = STORE.transaction { STORE[:current_week_index] } || 0
    current_week_name = WEEKS[current_week_index]
    formatted_deadline = format_deadline(new_deadline)

    begin
      # Update the persistent embed
      original_embed = message.embeds.first
      new_title = original_embed.title || "#{current_week_name} has started!"
      new_description = "🏈 The deadline to complete your recruiting and games is #{formatted_deadline}. 🏈"

      embed = create_embed(new_title, new_description, original_embed.color || 0x00FF00, EMBED_IMAGE_URL,
                           FOOTER_TEXT, TROPHY_IMAGE_URL)
      message.edit('', embed)

      event.respond "Deadline updated to #{formatted_deadline}."

      # Construct the message link
      link = message_link(event.server.id, message.channel.id, message.id)

      # Send a ping to the lobby channel
      ping_message = "📢 @everyone, the **deadline** has been updated! 🏈\nNew Deadline: **#{formatted_deadline}**.\nView the full announcement here: [Click to view](#{link})"
      send_lobby_notification(event.server, ping_message)
    rescue Discordrb::Errors::NoPermission
      event.respond "I don't have permission to edit messages in the 'week-advances' channel. Please check my permissions."
    end
  end
end
