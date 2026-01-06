class ChatsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_chat, only: [ :show, :edit, :update, :destroy ]

  def index
    @chat = nil # override application_controller default behavior of setting @chat to last viewed chat
    @chats = Current.user.chats.order(created_at: :desc)
    set_page_context
  end

  def show
    set_last_viewed_chat(@chat)
    set_page_context
  end

  def new
    @chat = Current.user.chats.new(title: "New chat #{Time.current.strftime("%Y-%m-%d %H:%M")}")
    set_page_context
    @initial_prompt = params[:prompt]
  end

  def create
    @chat = Current.user.chats.start!(chat_params[:content], model: chat_params[:ai_model])
    set_last_viewed_chat(@chat)
    redirect_to chat_path(@chat, thinking: true)
  end

  def edit
  end

  def update
    @chat.update!(chat_params)

    respond_to do |format|
      format.html { redirect_back_or_to chat_path(@chat), notice: "Chat updated" }
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@chat, :title), partial: "chats/chat_title", locals: { chat: @chat }) }
    end
  end

  def destroy
    @chat.destroy
    clear_last_viewed_chat

    redirect_to chats_path, notice: "Chat was successfully deleted"
  end

  def retry
    @chat.retry_last_message!
    redirect_to chat_path(@chat, thinking: true)
  end

  private
    def set_chat
      @chat = Current.user.chats.find(params[:id])
    end

    def set_last_viewed_chat(chat)
      Current.user.update!(last_viewed_chat: chat)
    end

    def clear_last_viewed_chat
      Current.user.update!(last_viewed_chat: nil)
    end

    def chat_params
      params.require(:chat).permit(:title, :content, :ai_model)
    end

    def set_page_context
      @page_context = params[:page_context]&.to_sym
      @page_metadata = parse_page_metadata
    end

    def parse_page_metadata
      return {} unless params[:metadata].present?

      JSON.parse(params[:metadata]).with_indifferent_access
    rescue JSON::ParserError
      {}
    end
end
