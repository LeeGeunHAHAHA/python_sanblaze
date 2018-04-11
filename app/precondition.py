import device
import json
from random import randint
import time
from sanpyutil import echo
from sanpyutil import grep
import re




"""
device information


device_name = None #device name.
port_num = None #port num that device is connected.
dual_mode = None #dual =1 , single =0
functions = {"phyFuncs": [], "vFuncs": []}

"""

"""

function information

device = None
phy_or_vir = None #(0 = vir, 1 =phy)
function_name = None
num_of_LUN = None
num_of_queue = None
queue_depth = None
type_of_CMB = None
type_of_interrupt = None #legacy = 0, msi = 1, msi-x =2

"""
def tmp_log(message):
    print("this part will be replaced by log. {0}".format(message))

def pre_enable_CMB(type_of_CMB, port_num, target_name):

    CMB_type=  type_of_CMB
    CMB_target = "/iport" + port_num + "/target" + target_name
    CMB_file = open(CMB_target, "w")
    CMB_file.write("UseCMB="+str(CMB_type))
    CMB_file.close()
    tmp_log("CMB enabled")


def pre_vf_enable_configure(device):
    port_num = device.port_num
    target_PF_list = device.functions["phyFuncs"]

    restart_file = open("/proc/vlun/nvme")
    for idx, each_pf in enumerate(target_PF_list):

        PF_target = "/iport" + port_num + "/target" + each_pf.function_name
        PF_file = open(PF_target,"w")
        PF_file.write("NumVFs=0")
        tmp_log("vf = 0 for stable")
        time.sleep(3)
        if not each_pf.same_option_each_pf_function and idx is 1 :
            pre_enable_CMB(each_pf.type_of_CMB, port_num, each_pf.function_name)
        else:
            pre_enable_CMB(str(randint(0,3)), port_num, each_pf.function_name)

        restart_file.write("restart="+ each_pf.function_name)

    time.slee(10)

    for idx, each_pf in enumerate(target_PF_list):

        PF_target = "/iport" + port_num + "/target" + each_pf.function_name
        PF_file = open(PF_target, "w")
        PF_file.write("NumVFs="+each_pf.num_of_vf)
        tmp_log("enable virtual function")
        time.sleep(10)

    def vf_configure():
        print("not implemented. This will be used for modfying enable information given device")
    return vf_configure()

def pre_initialize(device):

    port_num = device.port_num
    PF_list = device.functions["phyFuncs"]
    VF_list = device.functions["vFuncs"]

    stop_clear_addr = "/iport"+port_num+"/target"

    for each_pf in PF_list:
        stop_clear_file = open(stop_clear_addr+each_pf.function_name)
        stop_clear_file.write("StopTests")
        stop_clear_file.write("ClearTests")

    for each_vf in VF_list:
        stop_clear_file = open(+stop_clear_addr+each_vf.function_name)
        stop_clear_file.write("StopTests")
        stop_clear_file.write("ClearTests")

    port_file = open("/iport"+port_num+"/port")
    port_file.write("TimeoutErrorRecovery=0")
    port_file.write("TestLimits=0,0,0")

    admin_cmd_addr ="/sys/module/nvme/parameters/"
    echo(admin_cmd_addr+"admin_timeout", "20000")
    echo(admin_cmd_addr+"abort_timeout", "30000")



def pre_get_max_lba(device):

    maxblock = "-1"
    port_num = device.port_num
    target = device.functions["phyFuncs"][0]
    result = grep("/iport"+port_num+"/target"+target+"lun1", "blocks")
    patern = re.compile("\d+ blocks")
    found = []
    for line in result:
        found = patern.findall(line)
    return found.pop()[:-6]







if __name__ == "__main__":
    echo("123", "123")

    with open("device_input.json") as file:
        data = json.loads(file.read())
    device.device_configuration(**data)






