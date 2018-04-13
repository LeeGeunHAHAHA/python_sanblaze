def echo(addr, keyword):
    target_file = open(addr, "w")
    target_file.write(keyword)

def grep(file_addr, keyword):
    target_file = open(file_addr, "r")
    possible = target_file.readlines()
    for line in possible:
        if line.find(keyword) >= 0:
            possible.remove(line)
    return possible

def log_echo():
    pass

def status_check():
    pass

def get_status_check():
    pass

def run_in_background():
    pass

def kill_BG_job():
    pass





if __name__== "__main__":
    echo("./Test", "This 'ehco method write this str.")
