def info(message):
    print_color("{RESET}[ ⚠️  ]\t{YELLOW}" + message + "{RESET}")

def ok(message):
    print_color("{RESET}[ 👍  ]\t{GREEN}" + message + "{RESET}")

def error(message):
    print_color("{RESET}[ 💀  ]\t{RED}" + message + "{RESET}")

def header(message):
    print_color("{RESET}= {BLUE}" + message + "{RESET} " + "="*(70-len(message)))