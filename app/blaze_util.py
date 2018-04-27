import os
import re
import time
import blaze_precondition as pre
import threading

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

def log_echo(log_file = None):

    def log(message):
        file = open(log_file, "a")
        print(message)
        file.writelines(message+"\n")
    return log




def get_test_status(device, test_name):
    """
    status means
    0 => stiil testing
    -1 => error (Failed/ Failed to start)
    1 => passed
    @return status

    """
    port_num = device.port_num
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

def status_check(device, test_list, polling_time):


    for each_test in test_list:
        log_echo("test name is{0}". format(each_test))
        status = get_test_status(device, each_test)
        while status is 0:
            time.sleep(polling_time)
            status = get_test_status(device, each_test)
        if status is 1:
            log_echo("Test {0} is passed.".format(each_test))

        else:
            log_echo("Test {0} is failed.".format(each_test))
            pre.pre_finish_test(device, True)

def get_max_LBA(device):

    port_num = device.port_num
    target = device.functions["phyFuncs"][0]
    result = grep("/iport"+port_num+"/target"+target+"lun1", "blocks")
    patern = re.compile("\d+ blocks")
    found = []
    for line in result:
        found = patern.findall(line)
    return found.pop()[:-6] if found is not [] else -1


def set_simultaneous_NS(device, runtype):

    LUN_list = []
    if runtype is 0:
        for each_func in device.function:
            LUN_list.append(each_func.LUNS[0])

    if runtype is 1:
        for each_func in device.function["phyFuncs"]:
            LUN_list.append(each_func.LUNS[0])
        for each_func in device.function["vFuncs"]:
            LUN_list.append(each_func.LUNS[0])

    if runtype is 2:
        for each_func in device.function["phyFuncs"]:
            LUN_list += each_func.LUNS
        for each_func in device.function["vFuncs"]:
            LUN_list += each_func.LUNS

    return LUN_list


def get_block_size(device):
    block_list = []
    port_num = device.port_num
    phyfunc = device.functions["phyFuncs"][0]
    for target in phyfunc.LUNs:
        result = grep("/iport"+port_num+"/target"+target+"lun1", "blocks")
        patern = re.compile("\d+ blocks")
        found = []
        for line in result:
            found = patern.findall(line)
        block_list.append(found.pop()[:-6] if found is not [] else -1)
    return block_list


class BackGroundJob(threading.Thread):

    args = None
    def __init__(self, run_in_bg_function, *args):
        threading.Thread.__init__(self, target=run_in_bg_function, args=args)
        self.runnable = run_in_bg_function
        self.daemon = True
        self.args = args

    def run(self):
        self.runnable(self.args)

def do_back_ground_job(some_func,*args, thread_list):

    back_ground_function = BackGroundJob(some_func, args)
    thread_list.append(back_ground_function)
    back_ground_function.run()






def kill_BG_job(threads):

    for th in threads:
        th.join()




if __name__== "__main__":
    echo("./Test", "This 'ehco method write this str.")
