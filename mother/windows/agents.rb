# windows/agent.rb

require_relative 'window_base'

module Windows
  class Agents < WindowBase
    attr_reader :window

    def initialize(main_window, agents_count)
      super(main_window)
      @agents_count = agents_count
      @window = create_agents_subwindow
    end

    def refresh
      @window.refresh
    end

    private

    def create_agents_subwindow
      agents_subwindow_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
      agents_subwindow_height = BORDER_SPACE + (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH) + @agents_count + 3 # 3 works, don't ask me why
      create_window(agents_subwindow_height, agents_subwindow_width, PADDING_HEIGHT + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)
    end
  end
end
