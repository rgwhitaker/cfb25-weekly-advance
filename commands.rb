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

    begin
      update_embed_message(message, "#{next_week_name} has started!", description, message.embeds.first)
      event.respond "Week advanced to #{next_week_name}, and the deadline is set to #{advance_time_str}."

      # Construct the message link
      link = message_link(event.server.id, message.channel.id, message.id)

      # Notify the lobby
      notify_lobby(event.server, "week has advanced to **#{next_week_name}**", advance_time_str, link)
    rescue Discordrb::Errors::NoPermission
      event.respond "I don't have permission to edit messages in the 'week-advances' channel. Please check my permissions."
    end
  end

  # Command to set the current week manually
  bot.command :set_week do |event, *week_parts|
    message = get_or_create_week_message(event, STORE)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create the message."
      next
    end

    week = week_parts.join(" ").strip

    begin
      current_week_index = STORE.transaction { STORE[:current_week_index] } || 0

      # Determine the new week index
      if week =~ /^\d+$/  # Check if the week is a number
        week_number = week.to_i
        if week_number < 1 || week_number > WEEKS.length
          event.respond "Invalid week number. Please provide a number between 1 and #{WEEKS.length}."
          next
        end
        current_week_index = week_number - 1
      else  # Match week by name
        matching_week = WEEKS.find { |w| w.downcase.include?(week.downcase) }
        if matching_week.nil?
          event.respond "Invalid week name. Please provide a valid week name or number. Use partial names like 'Week 1' or 'Championship'."
          next
        end
        current_week_index = WEEKS.index(matching_week)
      end

      # Update the current week index in the datastore
      STORE.transaction do
        STORE[:current_week_index] = current_week_index
      end

      current_week_name = WEEKS[current_week_index]

      # Extract the current deadline text directly from the embed
      current_embed = message.embeds.first
      current_description = current_embed.description || ""
      deadline_text_match = current_description.match(/The deadline to complete your recruiting and games is (.+?)\./)

      # Preserve the existing deadline text if found
      if deadline_text_match
        existing_deadline_text = deadline_text_match[1]
      else
        existing_deadline_text = "No deadline set"
      end

      # Update the embed with the new week name but keep the deadline text unchanged
      new_title = "#{current_week_name} has started!"
      new_description = "🏈 The deadline to complete your recruiting and games is #{existing_deadline_text}. 🏈"

      begin
        # Update the embed message with the new week but unchanged deadline
        update_embed_message(message, new_title, new_description, current_embed)

        event.respond "Current week set to **#{current_week_name}**, and the deadline remains unchanged."

        # Construct the message link
        link = message_link(event.server.id, message.channel.id, message.id)

        # Send a ping to the lobby channel
        notify_lobby(event.server, "current week has been manually set to **#{current_week_name}**", existing_deadline_text, link)
      rescue Discordrb::Errors::NoPermission
        event.respond "I don't have permission to edit messages in the 'week-advances' channel. Please check my permissions."
      end
    rescue => e
      event.respond "An error occurred while setting the current week: #{e.message}"
    end
  end

  # Command to set the deadline manually
  bot.command :set_deadline do |event, *args|
    message = get_or_create_week_message(event, STORE)
    unless message
      event.respond "The 'week-advances' channel was not found or unable to create the message."
      next
    end

    input = args.join(" ").strip

    begin
      if Date::DAYNAMES.any? { |day| input.start_with?(day) }
        day_name, time_part = input.split(" at ", 2)
        target_time = next_weekday(day_name.capitalize)
        full_time = "#{target_time.strftime('%Y-%m-%d')} #{time_part.strip}"
        deadline = Time.parse(full_time).in_time_zone('Eastern Time (US & Canada)')
      else
        deadline = Time.parse(input).in_time_zone('Eastern Time (US & Canada)')
      end

      formatted_deadline = format_deadline(deadline.to_s)
      STORE.transaction { STORE[:current_deadline] = deadline.to_s }

      current_week_index = STORE.transaction { STORE[:current_week_index] } || 0
      current_week_name = WEEKS[current_week_index]

      update_embed_message(message,
                           message.embeds.first.title || "#{current_week_name} has started!",
                           "🏈 The deadline to complete your recruiting and games is #{formatted_deadline}. 🏈",
                           message.embeds.first
      )

      event.respond "Deadline updated to #{formatted_deadline}."
      link = message_link(event.server.id, message.channel.id, message.id)
      notify_lobby(event.server, "deadline has been updated", formatted_deadline, link)
    rescue => e
      event.respond "Invalid input for deadline. Please provide a valid date like `2023-11-28 00:00` or `Tuesday at 12:00AM`."
    end
  end

  def initialize_week_advances(bot, store)
    bot.command(:initialize) do |event|
      # Ensure the user has permissions
      unless event.user.has_permission?(:administrator) || event.user.id == event.server.owner.id
        event.respond("❌ You don't have permissions to initialize the bot.")
        next
      end

      # Step 1: Verify or create the 'week-advances' channel
      channel_name = 'week-advances'
      channel = event.server.channels.find { |ch| ch.name == channel_name }

      if channel.nil?
        begin
          channel = event.server.create_channel(channel_name, 'text') # Create the text channel
          event.respond("✅ Created new channel: `#{channel_name}`.")
        rescue StandardError => e
          event.respond("❌ Failed to create `#{channel_name}` channel: #{e.message}")
          next
        end
      else
        event.respond("✅ Found existing channel: `#{channel_name}`.")
      end

      # Step 2: Create or verify the week message
      saved_message_id = store.transaction { |data| data[:message_id] }

      if saved_message_id
        begin
          # Attempt to load the existing message
          existing_message = channel.load_message(saved_message_id.to_s)
          if existing_message
            event.respond("✅ Found existing week message with ID #{saved_message_id}.")
            next
          end
        rescue Discordrb::Errors::UnknownMessage
          event.respond("⚠️ Message ID #{saved_message_id} not found in `#{channel_name}`.")
        rescue StandardError => e
          event.respond("❌ Error loading message ID #{saved_message_id}: #{e.message}")
        end
      end

      # Step 3: If no valid message exists, create a new one
      begin
        embed = create_default_week_embed
        new_message = channel.send_message('', false, embed)

        # Save the message ID
        store.transaction do |data|
          data[:message_id] = new_message.id
          data[:current_week_index] = 0 # Bonus: Optionally initialize other state here
        end

        event.respond("✅ Created new week message and saved it with ID #{new_message.id}.")
      rescue StandardError => e
        event.respond("❌ Failed to create a new message in `#{channel_name}`: #{e.message}")
      end
    end

    def status_week_advances(bot, store)
      bot.command(:status) do |event|
        # Ensure the user has permissions
        unless event.user.has_permission?(:administrator) || event.user.id == event.server.owner.id
          event.respond("❌ You don't have permissions to view the bot's status.")
          next
        end

        # Retrieve the current state
        saved_message_id = store.transaction { |data| data[:message_id] }
        channel = event.server.channels.find { |ch| ch.name == 'week-advances' }

        status = "📊 **Bot Status**:\n"
        status += "- Channel: `#{channel.nil? ? 'Not Found' : channel.name}`\n"
        status += "- Stored Message ID: `#{saved_message_id || 'None'}`\n"

        # Check if the message still exists
        if saved_message_id && channel
          begin
            message = channel.load_message(saved_message_id.to_s)
            status += "- Message Status: ✅ Found\n"
          rescue Discordrb::Errors::UnknownMessage
            status += "- Message Status: ❌ Not Found (deleted?)\n"
          rescue StandardError => e
            status += "- Message Status: ❌ Error: #{e.message}\n"
          end
        else
          status += "- Message Status: ⚠️ Unknown (no message ID or channel mismatch)\n"
        end

        # Respond with the bot's current status
        event.respond(status)
      end
    end

    def reset_week_advances(bot, store)
      bot.command(:reset) do |event|
        # Ensure the user has administrator permissions
        unless event.user.has_permission?(:administrator) || event.user.id == event.server.owner.id
          event.respond("❌ You don't have permissions to reset the bot.")
          next
        end

        # Optionally confirm reset from the user
        event.respond("⚠️ Are you sure you want to reset the bot? Type `!confirm_reset` to proceed.")

        # You could implement confirmation logic or store a temp state here if desired
        bot.command(:confirm_reset) do |confirm_event|
          next unless event.user == confirm_event.user # Ensure it's the same user

          store.transaction do |data|
            data.clear # Clear all stored data
          end

          event.respond("✅ Bot state has been reset. Please run `!initialize` to set it up again.")
        end
      end
    end
  end
end