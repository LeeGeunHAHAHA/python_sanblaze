def echo(addr, target):
    target_file = open(addr,"w")
    target_file.write(target)

def grep(file_addr, keyword):
    target_file = open(file_addr,"r")
    possible = target_file.readlines()
    for line in possible:
        if line.find(keyword) >=0:
            possible.remove(line)
    return possible




if __name__== "__main__":
    echo("Test", "hey!")
