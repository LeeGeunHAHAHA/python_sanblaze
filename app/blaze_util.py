import os
import re
import time
import blaze_precondition as pre

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

def get_test_status(function, test_name):
    """
    status means
    0 => stiil testing
    -1 => error (Failed/ Failed to start)
    1 => passed
    @return status

    """
    port_num = function.device.port_num
    tests_base_addr = "/iport" + port_num +"/tests/"
    excuted_test_set = set(os.listdir(tests_base_addr))

    try:
        excuted_test_set.remove(test_name)
        with open(tests_base_addr + test_name, "r") as test_file:
            lines = test_file.readlines()
            for line in lines :
                if line.find("Passed"):
                    return 1
                if line.find("Failed"):
                    return -1
        return 0
    except KeyError:
        log_echo("fail to start")
        return -1

def status_check(function, test_list, polling_time):


    for each_test in test_list:
        log_echo("test name is{0}". format(each_test))
        status = get_test_status(function, each_test)
        while status is 0:
            time.sleep(polling_time)
            status = get_test_status(function, each_test)
        if status is 1:
            log_echo("Test {0} is passed.".format(each_test))

        else:
            log_echo("Test {0} is failed.".format(each_test))
            pre.pre_finish_test(function.device, True)

def get_max_LBA(device):

    port_num = device.port_num
    target = device.functions["phyFuncs"][0]
    result = grep("/iport"+port_num+"/target"+target+"lun1", "blocks")
    patern = re.compile("\d+ blocks")
    found = []
    for line in result:
        found = patern.findall(line)
    return found.pop()[:-6] if found is not [] else -1

def se_simultaneous_NS(function, runtype):
    selected_LUN = list()
    return selected_LUN


def run_in_background():
    pass

def kill_BG_job():
    pass





if __name__== "__main__":
    echo("./Test", "This 'ehco method write this str.")
