class Assistant::Responder
  # Maximum function calls allowed per conversation turn to control costs
  # This allows multi-step workflows and large bulk operations while preventing runaway API usage
  MAX_FUNCTION_CALLS = 100

  def initialize(message:, instructions:, function_tool_caller:, llm:)
    @message = message
    @instructions = instructions
    @function_tool_caller = function_tool_caller
    @llm = llm
    @total_calls_used = 0
  end

  def on(event_name, &block)
    listeners[event_name.to_sym] << block
  end

  def respond(previous_response_id: nil)
    # Track whether response was handled by streamer
    response_handled = false

    # For the first response
    streamer = proc do |chunk|
      case chunk.type
      when "output_text"
        emit(:output_text, chunk.data)
      when "response"
        response = chunk.data
        response_handled = true

        if response.function_requests.any?
          handle_follow_up_response(response)
        else
          emit(:response, { id: response.id })
        end
      end
    end

    response = get_llm_response(streamer: streamer, previous_response_id: previous_response_id)

    # For synchronous (non-streaming) responses, handle function requests if not already handled by streamer
    unless response_handled
      if response && response.function_requests.any?
        handle_follow_up_response(response)
      elsif response
        emit(:response, { id: response.id })
      end
    end
  end

  private
    attr_reader :message, :instructions, :function_tool_caller, :llm
    attr_accessor :total_calls_used

    def handle_follow_up_response(response)
      follow_up_response = nil
      had_text_output = false

      # Check budget BEFORE executing function calls
      call_count = response.function_requests.count
      remaining_budget = MAX_FUNCTION_CALLS - total_calls_used

      if call_count > remaining_budget
        # Budget would be exceeded - don't execute, return early
        Rails.logger.warn("Function call budget would be exceeded (#{total_calls_used}/#{MAX_FUNCTION_CALLS} used, #{call_count} requested)")
        emit(:output_text, build_budget_exhausted_message)
        emit(:response, { id: response.id, has_pending_functions: true })
        return
      end

      streamer = proc do |chunk|
        case chunk.type
        when "output_text"
          had_text_output = true
          emit(:output_text, chunk.data)
        when "response"
          follow_up_response = chunk.data
          # Response handling is done after streaming completes
          # to ensure we have full context about what was output
        end
      end

      # Track function calls against budget
      self.total_calls_used += call_count

      function_names = response.function_requests.map(&:function_name)
      Rails.logger.info("Functions starting (#{total_calls_used}/#{MAX_FUNCTION_CALLS} calls used) - function_names: #{function_names.inspect}")
      emit(:functions_starting, { function_names: function_names })

      function_tool_calls = function_tool_caller.fulfill_requests(response.function_requests)

      emit(:response, {
        id: response.id,
        function_tool_calls: function_tool_calls
      })

      get_llm_response(
        streamer: streamer,
        function_results: function_tool_calls.map(&:to_result),
        previous_response_id: response.id
      )

      # Handle the follow-up response after streaming completes
      if follow_up_response
        if follow_up_response.function_requests.any?
          requested_calls = follow_up_response.function_requests.count
          remaining_budget = MAX_FUNCTION_CALLS - total_calls_used

          if requested_calls <= remaining_budget
            # Budget allows more calls - recurse
            Rails.logger.info("Allowing #{requested_calls} more function calls (#{remaining_budget} remaining in budget)")
            handle_follow_up_response(follow_up_response)
          else
            # Budget exhausted
            Rails.logger.warn("Function call budget exhausted (#{total_calls_used}/#{MAX_FUNCTION_CALLS} used, #{requested_calls} requested)")

            # If no text was streamed, provide a fallback message
            unless had_text_output
              emit(:output_text, build_budget_exhausted_message)
            end

            # Emit response with flag so we don't save this ID (it expects function output)
            emit(:response, { id: follow_up_response.id, has_pending_functions: true })
          end
        else
          # Normal completion - AI returned text without more function requests
          emit(:response, { id: follow_up_response.id })
        end
      end
    end

    def build_budget_exhausted_message
      "I've gathered the available data but need to stop here to manage costs. " \
      "Let me know if you'd like me to continue with additional queries."
    end

    def get_llm_response(streamer:, function_results: [], previous_response_id: nil)
      response = llm.chat_response(
        message.content,
        model: message.ai_model,
        instructions: instructions,
        functions: function_tool_caller.function_definitions,
        function_results: function_results,
        streamer: streamer,
        previous_response_id: previous_response_id,
        session_id: chat_session_id,
        user_identifier: chat_user_identifier,
        family: message.chat&.user&.family
      )

      unless response.success?
        # If we get a 400 error with a previous_response_id, it's likely stale - retry without it
        if previous_response_id.present? && stale_response_id_error?(response.error)
          Rails.logger.warn("Stale previous_response_id detected, clearing and retrying without it")
          chat&.update_column(:latest_assistant_response_id, nil)

          response = llm.chat_response(
            message.content,
            model: message.ai_model,
            instructions: instructions,
            functions: function_tool_caller.function_definitions,
            function_results: function_results,
            streamer: streamer,
            previous_response_id: nil,
            session_id: chat_session_id,
            user_identifier: chat_user_identifier,
            family: message.chat&.user&.family
          )
        end

        raise response.error unless response.success?
      end

      response.data
    end

    def stale_response_id_error?(error)
      return false unless error.respond_to?(:message)

      error_msg = error.message.to_s.downcase

      # Only match specific patterns that indicate a stale/invalid previous_response_id
      # OpenAI Responses API returns errors when the response ID is invalid or expired
      stale_id_patterns = [
        /previous_response.*not found/,
        /previous_response.*invalid/,
        /previous_response.*does not exist/,
        /previous_response.*expired/,
        /response.*id.*not found/,
        /response.*id.*invalid/,
        # OpenAI may return 404 for missing resources or 400 with specific messages
        /no response found/,
        /conversation.*not found/
      ]

      stale_id_patterns.any? { |pattern| error_msg.match?(pattern) }
    end

    def emit(event_name, payload = nil)
      listeners[event_name.to_sym].each { |block| block.call(payload) }
    end

    def listeners
      @listeners ||= Hash.new { |h, k| h[k] = [] }
    end

    def chat_session_id
      chat&.id&.to_s
    end

    def chat_user_identifier
      return unless chat&.user_id

      ::Digest::SHA256.hexdigest(chat.user_id.to_s)
    end

    def chat
      @chat ||= message.chat
    end
end
