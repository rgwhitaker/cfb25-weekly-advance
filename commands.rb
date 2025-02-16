# commands.rb
require 'active_support/time'
require_relative 'config'
require_relative 'helpers'

def register_commands(bot)
  # Command to advance the week
  bot.command :advance_week do |event, duration_in_hours = '48'|
    message = get_or_create_week_message(event, STORE)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create message."
      next
    end

    current_week_index = STORE.transaction { STORE[:current_week_index] } || 0
    current_week_name = WEEKS[current_week_index]
    current_time = Time.now.in_time_zone('Eastern Time (US & Canada)')
    advance_time = calculate_advance_time(current_time, duration_in_hours)
    advance_time_str = advance_time.strftime('%A, %I:%M %p %Z')
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
      message.edit(content: "", embeds: [embed])
    rescue Discordrb::Errors::NoPermission
      event.respond "I don't have permission to edit messages in the 'week-advances' channel. Please check my permissions."
    end
  end

  # Command to set the current week manually
  bot.command :set_week do |event, week|
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
    description = "🏈 The current week is now #{current_week_name}. 🏈"
    embed = create_embed("Week has been set!", description, 0xFF4500, EMBED_IMAGE_URL,
                         FOOTER_TEXT, TROPHY_IMAGE_URL)

    event.channel.send_embed('', embed)
  end

  # Command to show the current week and deadline
  bot.command :current_week do |event|
    current_week_index = STORE.transaction { STORE[:current_week_index] } || 0
    current_week_name = WEEKS[current_week_index]
    current_deadline = STORE.transaction { STORE[:current_deadline] }
    description = "🏈 The deadline to complete your recruiting and games is #{current_deadline}. 🏈"
    embed = create_embed("Current Week: #{current_week_name}", description, 0x0000FF, EMBED_IMAGE_URL,
                         FOOTER_TEXT, TROPHY_IMAGE_URL)

    event.channel.send_embed('', embed)
  end
end
