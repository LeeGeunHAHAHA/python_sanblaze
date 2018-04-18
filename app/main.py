from multiprocessing import Pool
import multiprocessing
import time
from random import randint
import blaze_testcase
import blaze_device


class TC0:
    tc_name = None
    tc_data = None

    def __init__ (self, tc_name, tc_data):
        self.tc_name = tc_name
        self.tc_data = tc_data

    def do_test(self, device):
        print("testing : My Test Case_name is {0}, And My device_name is {1}".format(self.tc_name, device.device_name))
        time.sleep(randint(10,30) )
        return True


class TC1:
    tc_name = None
    tc_data = None

    def __init__ (self, tc_name, tc_data):
        self.tc_name = tc_name
        self.tc_data = tc_data

    def do_test(self, device):
        print("testing : 테스트 케이스 이름은 {0}, 디바이스 이름은 {1}".format(self.tc_name, device.device_name))
        time.sleep(randint(10,20))
        return True


class Device:

    device_name = None

    def __init__(self, device_name):
        self.device_name = device_name



def worker(*args):
    TC = args[-1][0]
    ready_dev_queue =args[-1][1]
    working_dev_list = args[-1][2]
    dev = ready_dev_queue.get()
    working_dev_list.append(dev)
    print("{0} is testing".format(TC.tc_name))
    print("this message will be replaced by log")
    done = TC.do_test(dev)
    if done:
        idx_dev = working_dev_list.index(dev)
        ready_dev_queue.put_nowait(working_dev_list[idx_dev])


if __name__ == "__main__":
    multi= multiprocessing.Manager()
    ready_dev_queue = multi.Queue()
    ready_dev_queue.put(Device("FADU"))
    ready_dev_queue.put(Device("SAMSUNG"))
    ready_dev_queue.put(Device("INTEL"))
    ready_dev_queue.put(Device("SKh"))
    """
    ready_dev_queue.put(blaze_device.device_configure()) 
    """

    working_dev_list = []
    TC_list = [TC0(name, randint(0, 5)) if randint(0, 2) else TC1(name, randint(0, 5)) for name in range(20)]

    """
    TC_list = get_TC_list() 
    """
    args = [(tc, ready_dev_queue, working_dev_list) for tc in TC_list]
    num_of_worker = ready_dev_queue.qsize()
    with Pool(processes=num_of_worker) as pool:
        res = pool.map_async(worker, args)
        res.get(timeout=1000)
