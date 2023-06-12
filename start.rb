require 'curses'

Curses.init_screen
Curses.start_color
Curses.init_pair(1, Curses::COLOR_GREEN, Curses::COLOR_BLACK) # for the bot window
Curses.init_pair(2, Curses::COLOR_CYAN, Curses::COLOR_BLACK)  # for Jason
Curses.init_pair(3, Curses::COLOR_MAGENTA, Curses::COLOR_BLACK) # for Mother
Curses.init_pair(4, Curses::COLOR_YELLOW, Curses::COLOR_BLACK) # for the chat box

# Create a window for the bot outputs
bot_window = Curses::Window.new(Curses.lines / 2 - 3, Curses.cols, 0, 0)
bot_window.box("|", "-")

# Create a window for the interaction
interaction_window = Curses::Window.new(Curses.lines / 2 - 1, Curses.cols, Curses.lines / 2 - 2, 0)
interaction_window.box("|", "-")

# Create a window for the chat box
chat_window = Curses::Window.new(3, Curses.cols, Curses.lines - 3, 0)
chat_window.box("|", "-")

bot_window.attron(Curses.color_pair(1))
bot_window.setpos(2, 2)
bot_window.addstr("BOTS:")
bot_window.setpos(3, 2)
bot_window.addstr("hello_bot     <output of hello_bot>")
bot_window.setpos(4, 2)
bot_window.addstr("other_bot     <output of other_bot>")
bot_window.attroff(Curses.color_pair(1))

interaction_window.attron(Curses.color_pair(2)) # Jason's color
interaction_window.setpos(2, 2)
interaction_window.addstr("Jason: Hi Mother!")
interaction_window.attroff(Curses.color_pair(2))

interaction_window.attron(Curses.color_pair(3)) # Mother's color
interaction_window.setpos(3, 2)
interaction_window.addstr("Mother: Hi Jason how can i help?")
interaction_window.attroff(Curses.color_pair(3))

chat_window.attron(Curses.color_pair(4)) # Chat box's color
chat_window.setpos(1, 2)
chat_window.addstr("Enter your message:")
chat_window.attroff(Curses.color_pair(4))

bot_window.refresh
interaction_window.refresh
chat_window.refresh

bot_window.getch
interaction_window.getch
chat_window.getch

Curses.close_screen
